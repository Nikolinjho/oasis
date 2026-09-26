import AudioToolbox
import CoreAudio
import Foundation
import os

/// Громкость и mute дефолтного выхода через CoreAudio
public final class VolumeControl: @unchecked Sendable {
    /// Любое изменение громкости или mute, в том числе чужое. Уровень 0…1, при mute — 0
    public let changes: AsyncStream<Double>
    private let continuation: AsyncStream<Double>.Continuation
    private let onChange: AudioObjectPropertyListenerBlock
    private let attached = OSAllocatedUnfairLock(initialState: AudioObjectID(kAudioObjectUnknown))
    private let log = SourceLog.logger("volume")

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        changes = stream
        self.continuation = continuation
        onChange = { _, _ in continuation.yield(VolumeControl.currentLevel()) }

        // дефолтный выход сменился (наушники, AirPlay): переподписываемся на новое устройство
        var defaultAddress = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main) { [weak self] _, _ in
            self?.attach(to: Self.defaultDevice())
        }
        attach(to: Self.defaultDevice())
    }

    /// Текущая громкость без учёта mute
    public var volume: Double? { Self.volume(of: Self.defaultDevice()) }

    public func setVolume(_ level: Double) {
        var address = Self.volumeAddress
        var value = Float32(level)
        let status = AudioObjectSetPropertyData(Self.defaultDevice(), &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status != noErr { log.error("set volume failed: \(status)") }
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

    private func attach(to device: AudioObjectID) {
        let previous = attached.withLock { current in
            defer { current = device }
            return current
        }
        guard previous != device else { return }
        var volumeAddress = Self.volumeAddress
        var muteAddress = Self.muteAddress
        if previous != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(previous, &volumeAddress, .main, onChange)
            AudioObjectRemovePropertyListenerBlock(previous, &muteAddress, .main, onChange)
        }
        AudioObjectAddPropertyListenerBlock(device, &volumeAddress, .main, onChange)
        AudioObjectAddPropertyListenerBlock(device, &muteAddress, .main, onChange)
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

    static func currentLevel() -> Double {
        let device = defaultDevice()
        return isMuted(device) ? 0 : volume(of: device) ?? 0
    }
}
