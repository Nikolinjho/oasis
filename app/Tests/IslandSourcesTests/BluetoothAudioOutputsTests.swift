import CoreAudio
import Testing

@testable import IslandSources

struct BluetoothAudioOutputsTests {
  @Test("Адрес из UID Bluetooth-выхода: «9C-F3-AC-7A-32-A5:output» → адрес, вход и не Bluetooth — nil")
  func address() {
    let bluetooth = kAudioDeviceTransportTypeBluetooth
    #expect(BluetoothAudioOutputs.address(uid: "9C-F3-AC-7A-32-A5:output", transport: bluetooth) == "9C-F3-AC-7A-32-A5")
    #expect(
      BluetoothAudioOutputs.address(uid: "9C-F3-AC-7A-32-A5:output", transport: kAudioDeviceTransportTypeBluetoothLE)
        == "9C-F3-AC-7A-32-A5")
    #expect(BluetoothAudioOutputs.address(uid: "9C-F3-AC-7A-32-A5:input", transport: bluetooth) == nil)
    #expect(BluetoothAudioOutputs.address(uid: ":output", transport: bluetooth) == nil)
    #expect(BluetoothAudioOutputs.address(uid: "BuiltInHeadphoneOutputDevice", transport: kAudioDeviceTransportTypeBuiltIn) == nil)
  }

  @Test("Первый снимок — исходный, не подключения; потом — только появившиеся выходы")
  func appeared() {
    let airpods = AirPodsBattery.Connection(name: "thegreatnikos", address: "9C-F3-AC-7A-32-A5")
    let speaker = AirPodsBattery.Connection(name: "JBL", address: "11-22-33-44-55-66")
    var tracker = BluetoothAudioOutputs.Tracker()
    let initial = tracker.update([airpods])
    #expect(initial.isEmpty)
    // кейс закрыли: выход пропал, Bluetooth-соединение при этом живо (замер 28.09)
    let closed = tracker.update([])
    #expect(closed.isEmpty)
    // достали из кейса: выход вернулся — это подключение
    let opened = tracker.update([airpods])
    #expect(opened == [airpods])
    // список сменился из-за другого устройства: AirPods не повторяются
    let other = tracker.update([airpods, speaker])
    #expect(other == [speaker])
  }
}
