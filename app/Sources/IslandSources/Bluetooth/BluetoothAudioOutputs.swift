import CoreAudio
import Foundation

/// Bluetooth-выходы CoreAudio. Наушники, убранные в кейс и сразу вынутые, не рвут Bluetooth-соединение:
/// IOBluetooth молчит, а CoreAudio убирает и возвращает их выход (замер 28.09). Появление выхода — тоже подключение
enum BluetoothAudioOutputs {
  /// Адрес из UID вида «9C-F3-AC-7A-32-A5:output»; не Bluetooth или вход — nil
  static func address(uid: String, transport: UInt32) -> String? {
    guard transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE,
      uid.hasSuffix(":output")
    else { return nil }
    let address = String(uid.dropLast(":output".count))
    return address.isEmpty ? nil : address
  }

  /// Какие выходы появились с прошлого снимка. Первый снимок — исходный: то, что было до старта, не подключение
  struct Tracker {
    private var known: Set<String>?

    mutating func update(_ current: [AirPodsBattery.Connection]) -> [AirPodsBattery.Connection] {
      let addresses = Set(current.compactMap { $0.address.map(AirPodsBattery.normalized(address:)) })
      defer { known = addresses }
      guard let known else { return [] }
      return current.filter { connection in
        connection.address.map { !known.contains(AirPodsBattery.normalized(address: $0)) } ?? false
      }
    }
  }

  /// Bluetooth-выходы, которые CoreAudio видит сейчас
  static func current() -> [AirPodsBattery.Connection] {
    deviceIDs().compactMap { id in
      guard let uid = string(kAudioDevicePropertyDeviceUID, of: id),
        let address = address(uid: uid, transport: transport(of: id)),
        let name = string(kAudioObjectPropertyName, of: id)
      else { return nil }
      return AirPodsBattery.Connection(name: name, address: address)
    }
  }

  // MARK: - CoreAudio

  static let system = AudioObjectID(kAudioObjectSystemObject)

  static var devicesAddress: AudioObjectPropertyAddress {
    address(kAudioHardwarePropertyDevices)
  }

  private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  }

  private static func deviceIDs() -> [AudioObjectID] {
    var address = devicesAddress
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
    return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
  }

  private static func string(_ selector: AudioObjectPropertySelector, of device: AudioObjectID) -> String? {
    var address = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
    return value?.takeRetainedValue() as String?
  }

  private static func transport(of device: AudioObjectID) -> UInt32 {
    var address = address(kAudioDevicePropertyTransportType)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return 0 }
    return value
  }
}
