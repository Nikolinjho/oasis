import CoreAudio
import Foundation
import Testing
@testable import IslandSources

/// Фейковое железо: список устройств и дефолт в памяти, запись дефолта запоминается
final class FakeAudioHardware: AudioHardware, @unchecked Sendable {
    var records: [AudioDeviceRecord]
    var defaultID: AudioObjectID
    var setStatus: OSStatus = noErr
    private(set) var setCalls: [AudioObjectID] = []

    init(records: [AudioDeviceRecord], defaultID: AudioObjectID) {
        self.records = records
        self.defaultID = defaultID
    }

    func deviceRecords() -> [AudioDeviceRecord] { records }
    func defaultOutputDevice() -> AudioObjectID { defaultID }
    func setDefaultOutputDevice(_ id: AudioObjectID) -> OSStatus {
        setCalls.append(id)
        if setStatus == noErr { defaultID = id }
        return setStatus
    }
}

struct OutputDevicesTests {
    static let speakers = AudioDeviceRecord(id: 91, name: "Динамики MacBook Pro", outputChannels: 2, canBeDefault: true, isHidden: false)
    static let airpods = AudioDeviceRecord(id: 120, name: "AirPods Pro", outputChannels: 2, canBeDefault: true, isHidden: false)
    static let mic = AudioDeviceRecord(id: 84, name: "Микрофон MacBook Pro", outputChannels: 0, canBeDefault: false, isHidden: false)
    static let aggregate = AudioDeviceRecord(id: 130, name: "CADefaultDeviceAggregate", outputChannels: 2, canBeDefault: true, isHidden: true)
    static let loopback = AudioDeviceRecord(id: 140, name: "Loopback", outputChannels: 2, canBeDefault: false, isHidden: false)

    @Test("В список попадают только выходы, которые можно сделать дефолтными, в порядке CoreAudio")
    func filtersOutputs() {
        let list = OutputDeviceList.make([Self.mic, Self.speakers, Self.aggregate, Self.loopback, Self.airpods], defaultID: 91)
        #expect(list.map(\.name) == ["Динамики MacBook Pro", "AirPods Pro"])
        #expect(list.map(\.id) == [91, 120])
    }

    @Test("Отмечено ровно текущее устройство по умолчанию")
    func marksDefault() {
        let list = OutputDeviceList.make([Self.speakers, Self.airpods], defaultID: 120)
        #expect(list.filter(\.isDefault).map(\.id) == [120])
    }

    @Test("Дефолт не из списка (скрытый агрегат) — ничего не отмечено")
    func unknownDefault() {
        let list = OutputDeviceList.make([Self.speakers, Self.airpods, Self.aggregate], defaultID: 130)
        #expect(list.allSatisfy { !$0.isDefault })
    }

    @Test("Устройство без имени не показываем")
    func skipsNameless() {
        let nameless = AudioDeviceRecord(id: 7, name: "", outputChannels: 2, canBeDefault: true, isHidden: false)
        #expect(OutputDeviceList.make([nameless, Self.speakers], defaultID: 91).map(\.id) == [91])
    }

    @Test("list берёт устройства и дефолт у железа")
    func listFromHardware() {
        let hardware = FakeAudioHardware(records: [Self.speakers, Self.airpods], defaultID: 91)
        let list = OutputDevices(hardware: hardware).list()
        #expect(list == [
            OutputDevice(id: 91, name: "Динамики MacBook Pro", isDefault: true),
            OutputDevice(id: 120, name: "AirPods Pro", isDefault: false),
        ])
    }

    @Test("select переключает дефолт на выбранное устройство")
    func selectSwitches() {
        let hardware = FakeAudioHardware(records: [Self.speakers, Self.airpods], defaultID: 91)
        #expect(OutputDevices(hardware: hardware).select(120))
        #expect(hardware.setCalls == [120])
    }

    @Test("select текущего устройства ничего не пишет")
    func selectCurrent() {
        let hardware = FakeAudioHardware(records: [Self.speakers, Self.airpods], defaultID: 91)
        #expect(OutputDevices(hardware: hardware).select(91))
        #expect(hardware.setCalls.isEmpty)
    }

    @Test("select пропавшего или неподходящего устройства не пишет и возвращает false")
    func selectUnknown() {
        let hardware = FakeAudioHardware(records: [Self.speakers, Self.mic], defaultID: 91)
        let devices = OutputDevices(hardware: hardware)
        #expect(!devices.select(120))
        #expect(!devices.select(84))
        #expect(hardware.setCalls.isEmpty)
    }

    @Test("Ошибка CoreAudio при записи — false")
    func selectFails() {
        let hardware = FakeAudioHardware(records: [Self.speakers, Self.airpods], defaultID: 91)
        hardware.setStatus = -50
        #expect(!OutputDevices(hardware: hardware).select(120))
    }
}

/// Живая проверка списка без переключения: AUDIO_TESTS=1 swift test --filter liveOutputDevices
@Test("Живой CoreAudio отдаёт выходы и ровно один дефолтный", .enabled(if: ProcessInfo.processInfo.environment["AUDIO_TESTS"] == "1"))
func liveOutputDevices() {
    let list = OutputDevices().list()
    print("output devices:", list.map { "\($0.isDefault ? "✓" : " ") \($0.id) \($0.name)" })
    #expect(!list.isEmpty)
    #expect(list.filter(\.isDefault).count == 1)
}
