import AudioToolbox
import CoreAudio
import Foundation
import IslandCore
import os

/// Громкость и mute выхода в момент уведомления
struct VolumeState: Equatable {
    let volume: Double?
    let muted: Bool

    /// Уровень для HUD: при mute — 0
    var level: Double { muted ? 0 : volume ?? 0 }
}

/// Устройство, на котором висят слушатели громкости и mute, и последнее показанное состояние
struct ListenedDevice: Equatable {
    struct Switch: Equatable {
        let attach: AudioObjectID
        let detach: AudioObjectID?
    }

    private(set) var current = AudioObjectID(kAudioObjectUnknown)
    private var reported: VolumeState?

    /// nil — устройство то же, делать нечего. baseline — состояние нового устройства: оно не событие
    mutating func switchTo(_ device: AudioObjectID, baseline: VolumeState) -> Switch? {
        guard device != current else { return nil }
        let previous = current
        current = device
        reported = baseline
        return Switch(attach: device, detach: previous == kAudioObjectUnknown ? nil : previous)
    }

    /// true — громкость или mute правда изменились, показываем HUD.
    /// Только что подключённые AirPods шлют 2–4 уведомления о громкости с тем же уровнем (замер 28.09)
    mutating func report(_ state: VolumeState) -> Bool {
        guard state != reported else { return false }
        reported = state
        return true
    }
}

/// Громкость и mute дефолтного выхода через CoreAudio
public final class VolumeControl: @unchecked Sendable {
    /// Любое изменение громкости или mute, в том числе чужое. Уровень 0…1, при mute — 0
    public let changes: AsyncStream<Double>
    private let continuation: AsyncStream<Double>.Continuation
    /// Текущий выход: при старте и при каждой смене дефолтного устройства
    public let outputs: AsyncStream<OutputDeviceInfo>
    private let outputContinuation: AsyncStream<OutputDeviceInfo>.Continuation
    private let onChange: AudioObjectPropertyListenerBlock
    private let listened: OSAllocatedUnfairLock<ListenedDevice>
    private let log = SourceLog.logger("volume")

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        changes = stream
        self.continuation = continuation
        (outputs, outputContinuation) = AsyncStream.makeStream(of: OutputDeviceInfo.self, bufferingPolicy: .bufferingNewest(1))
        let listened = OSAllocatedUnfairLock(initialState: ListenedDevice())
        self.listened = listened
        onChange = { _, _ in
            let state = VolumeControl.currentState()
            if listened.withLock({ $0.report(state) }) { continuation.yield(state.level) }
        }

        // дефолтный выход сменился (наушники, AirPlay, меню плеера): только переподписываемся на новое устройство.
        // HUD при смене не показываем, как и сама macOS (решение 28.09): он вытеснял компакт подключённых AirPods.
        // Уровень нового устройства запоминаем как исходный: HUD — только когда он правда сменится
        var defaultAddress = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main) { [weak self] _, _ in
            self?.attach(to: Self.defaultDevice())
        }
        attach(to: Self.defaultDevice())
    }

    /// Текущая громкость без учёта mute
    public var volume: Double? { Self.volume(of: Self.defaultDevice()) }

    /// Уровень для HUD и строки громкости — та же логика, что у changes (VolumeState.level): 0 при mute.
    /// Оба должны сходиться в одной цифре, иначе строка мигала бы то реальным уровнем, то нулём
    public var level: Double { Self.currentState().level }

    public func setVolume(_ level: Double) {
        var address = Self.volumeAddress
        var value = Float32(level)
        let status = AudioObjectSetPropertyData(Self.defaultDevice(), &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status != noErr { log.error("set volume failed: \(status)") }
    }

    /// Строка громкости: уровень по месту клика/перетаскивания, mute снимается — как у клавиши (step).
    /// Без этого при замьюченном выходе уровень снаружи (VolumeState.level) остался бы 0, и строка
    /// тут же откатилась бы назад при первом же уведомлении CoreAudio о смене громкости
    public func setVolumeUnmuted(_ level: Double) {
        if Self.isMuted(Self.defaultDevice()) { setMuted(false) }
        setVolume(level)
    }

    /// Шаг клавиши; при mute сначала снимает его
    public func step(up: Bool, fine: Bool) {
        let device = Self.defaultDevice()
        if Self.isMuted(device) { setMuted(false) }
        setVolume(LevelStep.apply(Self.volume(of: device) ?? 0, up: up, fine: fine))
    }

    public func toggleMute() {
        setMuted(!Self.isMuted(Self.defaultDevice()))
    }

    private func setMuted(_ muted: Bool) {
        var address = Self.muteAddress
        var value: UInt32 = muted ? 1 : 0
        let status = AudioObjectSetPropertyData(Self.defaultDevice(), &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        if status != noErr { log.error("set mute failed: \(status)") }
    }

    @discardableResult
    private func attach(to device: AudioObjectID) -> ListenedDevice.Switch? {
        let baseline = Self.state(of: device)
        guard let change = listened.withLock({ $0.switchTo(device, baseline: baseline) }) else { return nil }
        var volumeAddress = Self.volumeAddress
        var muteAddress = Self.muteAddress
        if let previous = change.detach {
            AudioObjectRemovePropertyListenerBlock(previous, &volumeAddress, .main, onChange)
            AudioObjectRemovePropertyListenerBlock(previous, &muteAddress, .main, onChange)
        }
        AudioObjectAddPropertyListenerBlock(change.attach, &volumeAddress, .main, onChange)
        AudioObjectAddPropertyListenerBlock(change.attach, &muteAddress, .main, onChange)
        outputContinuation.yield(Self.outputInfo(change.attach))
        return change
    }

    // MARK: - CoreAudio

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
    }

    static func defaultDevice() -> AudioObjectID {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }

    static func volume(of device: AudioObjectID) -> Double? {
        var address = volumeAddress
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    static func isMuted(_ device: AudioObjectID) -> Bool {
        var address = muteAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    static func state(of device: AudioObjectID) -> VolumeState {
        VolumeState(volume: volume(of: device), muted: isMuted(device))
    }

    static func currentState() -> VolumeState { state(of: defaultDevice()) }

    static func outputInfo(_ device: AudioObjectID) -> OutputDeviceInfo {
        OutputDeviceInfo(
            transport: uint32(kAudioDevicePropertyTransportType, of: device),
            uid: string(kAudioDevicePropertyDeviceUID, of: device) ?? "",
            name: string(kAudioObjectPropertyName, of: device) ?? "")
    }

    private static func uint32(_ selector: AudioObjectPropertySelector, of device: AudioObjectID) -> UInt32 {
        var address = address(selector, scope: kAudioObjectPropertyScopeGlobal)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func string(_ selector: AudioObjectPropertySelector, of device: AudioObjectID) -> String? {
        var address = address(selector, scope: kAudioObjectPropertyScopeGlobal)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}

/// Что CoreAudio знает о выходе: для OutputDeviceKind.classify
public struct OutputDeviceInfo: Equatable, Sendable {
    public let transport: UInt32
    public let uid: String
    public let name: String

    public init(transport: UInt32, uid: String, name: String) {
        self.transport = transport
        self.uid = uid
        self.name = name
    }
}

extension OutputDeviceKind {
    /// knownHeadphones — нормализованный адрес → модель наушников, о которых сообщил BluetoothWatcher:
    /// переименованные AirPods («thegreatnikos») по имени не узнать, адрес — в UID Bluetooth-выхода
    public static func classify(
        transport: UInt32, uid: String, name: String, knownHeadphones: [String: AirPodsInfo.Model?]
    ) -> OutputDeviceKind {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return uid.contains("Headphone") ? .headphones : .speakers
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if let address = BluetoothAudioOutputs.address(uid: uid, transport: transport),
               let model = knownHeadphones[AirPodsBattery.normalized(address: address)] {
                return .airpods(model)
            }
            if name.localizedCaseInsensitiveContains("AirPods") {
                let symbol = AirPodsInfo(name: name, battery: nil).symbol
                return .airpods(symbol == "airpodsmax" ? .max : symbol == "airpodspro" ? .pro : nil)
            }
            // прочие Bluetooth-выходы у этой машины — наушники (Beats, JBL); колонки — редкость, оценка
            return .headphones
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .display
        default:
            return .other
        }
    }
}
