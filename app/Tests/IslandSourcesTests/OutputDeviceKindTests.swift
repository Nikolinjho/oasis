import CoreAudio
import IslandCore
import Testing
@testable import IslandSources

struct OutputDeviceKindTests {
    static let known: [String: AirPodsInfo.Model?] = ["9cf3ac7a32a5": .pro]

    static func kind(_ transport: UInt32, uid: String, name: String) -> OutputDeviceKind {
        OutputDeviceKind.classify(transport: transport, uid: uid, name: name, knownHeadphones: known)
    }

    @Test("Устройство вывода по транспорту, UID и известным наушникам")
    func classify() {
        #expect(Self.kind(kAudioDeviceTransportTypeBuiltIn, uid: "BuiltInSpeakerDevice", name: "MacBook Pro Speakers") == .speakers)
        #expect(Self.kind(kAudioDeviceTransportTypeBuiltIn, uid: "BuiltInHeadphoneOutputDevice", name: "External Headphones") == .headphones)
        // переименованные AirPods: имя модель не выдаёт, узнаём по адресу из UID
        #expect(Self.kind(kAudioDeviceTransportTypeBluetooth, uid: "9C-F3-AC-7A-32-A5:output", name: "thegreatnikos") == .airpods(.pro))
        #expect(Self.kind(kAudioDeviceTransportTypeBluetooth, uid: "11-22:output", name: "AirPods Max") == .airpods(.max))
        #expect(Self.kind(kAudioDeviceTransportTypeBluetoothLE, uid: "33-44:output", name: "JBL Tune") == .headphones)
        #expect(Self.kind(kAudioDeviceTransportTypeHDMI, uid: "x", name: "LG") == .display)
        #expect(Self.kind(kAudioDeviceTransportTypeVirtual, uid: "BGMDevice", name: "Background Music") == .other)
    }

    @Test("Глиф устройства")
    func symbols() {
        #expect(OutputDeviceKind.speakers.symbol == "laptopcomputer")
        #expect(OutputDeviceKind.headphones.symbol == "headphones")
        #expect(OutputDeviceKind.airpods(.pro).symbol == "airpodspro")
        #expect(OutputDeviceKind.airpods(nil).symbol == "airpods")
        #expect(OutputDeviceKind.display.symbol == "display")
        #expect(OutputDeviceKind.other.symbol == "speaker.wave.2.fill")
    }
}
