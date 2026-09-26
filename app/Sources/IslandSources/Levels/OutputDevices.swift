import CoreAudio
import Foundation
import os

/// Устройство вывода звука для меню выбора
public struct OutputDevice: Equatable, Sendable {
    public let id: AudioObjectID
    public let name: String
    public let isDefault: Bool

    public init(id: AudioObjectID, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

/// Что CoreAudio знает об устройстве, до фильтрации
struct AudioDeviceRecord: Equatable, Sendable {
    let id: AudioObjectID
    let name: String
    let outputChannels: Int
    let canBeDefault: Bool
    let isHidden: Bool
}

enum OutputDeviceList {
    /// Оставляет выходы, которые система сама предложила бы в настройках звука, и отмечает дефолтный
    static func make(_ records: [AudioDeviceRecord], defaultID: AudioObjectID) -> [OutputDevice] {
        records
            .filter { $0.outputChannels > 0 && $0.canBeDefault && !$0.isHidden && !$0.name.isEmpty }
            .map { OutputDevice(id: $0.id, name: $0.name, isDefault: $0.id == defaultID) }
    }
}

/// Тонкий слой над CoreAudio: в тестах подменяется фейком
protocol AudioHardware: Sendable {
    func deviceRecords() -> [AudioDeviceRecord]
    func defaultOutputDevice() -> AudioObjectID
    func setDefaultOutputDevice(_ id: AudioObjectID) -> OSStatus
}

/// Список устройств вывода и переключение устройства по умолчанию
public final class OutputDevices: Sendable {
    private let hardware: any AudioHardware
    private let log = SourceLog.logger("output")

    public convenience init() {
        self.init(hardware: CoreAudioHardware())
    }

    init(hardware: any AudioHardware) {
        self.hardware = hardware
    }

    public func list() -> [OutputDevice] {
        OutputDeviceList.make(hardware.deviceRecords(), defaultID: hardware.defaultOutputDevice())
    }

    /// true — устройство выбрано (или уже было выбрано). Громкость подхватит слушатель VolumeControl
    @discardableResult
    public func select(_ id: AudioObjectID) -> Bool {
        guard let device = list().first(where: { $0.id == id }) else {
            log.error("output device \(id) is gone or not an output")
            return false
        }
        if device.isDefault { return true }
        let status = hardware.setDefaultOutputDevice(id)
        guard status == noErr else {
            log.error("set default output \(id) failed: \(status)")
            return false
        }
        log.info("default output: \(device.name, privacy: .public)")
        return true
    }
}

// MARK: - CoreAudio

struct CoreAudioHardware: AudioHardware {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    func deviceRecords() -> [AudioDeviceRecord] {
        Self.deviceIDs().map { id in
            AudioDeviceRecord(
                id: id,
                name: Self.name(of: id) ?? "",
                outputChannels: Self.outputChannels(of: id),
                canBeDefault: Self.flag(kAudioDevicePropertyDeviceCanBeDefaultDevice, of: id, scope: kAudioDevicePropertyScopeOutput),
                isHidden: Self.flag(kAudioDevicePropertyIsHidden, of: id, scope: kAudioObjectPropertyScopeGlobal))
        }
    }

    func defaultOutputDevice() -> AudioObjectID { VolumeControl.defaultDevice() }

    func setDefaultOutputDevice(_ id: AudioObjectID) -> OSStatus {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var value = id
        return AudioObjectSetPropertyData(Self.system, &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value)
    }

    private static func deviceIDs() -> [AudioObjectID] {
        var address = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private static func name(of device: AudioObjectID) -> String? {
        var address = address(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    /// Сумма каналов выходных потоков: у входов (микрофон) их нет
    private static func outputChannels(of device: AudioObjectID) -> Int {
        var address = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, list) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func flag(_ selector: AudioObjectPropertySelector, of device: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = address(selector, scope: scope)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }
}
