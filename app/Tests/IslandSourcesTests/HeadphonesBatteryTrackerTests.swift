import Testing
@testable import IslandSources

struct HeadphonesBatteryTrackerTests {
    @Test("Подключение с зарядом ниже порога — предупреждение сразу, выше — нет")
    func onConnect() {
        var tracker = HeadphonesBatteryTracker()
        let low = tracker.connected(address: "aa-bb", level: 0.15, threshold: 0.2)
        #expect(low)
        let high = tracker.connected(address: "cc-dd", level: 0.5, threshold: 0.2)
        #expect(!high)
        let unknown = tracker.connected(address: "ee-ff", level: nil, threshold: 0.2)
        #expect(!unknown)
    }

    @Test("Опрос: предупреждение один раз при пересечении порога сверху, снова — после подъёма выше")
    func crossing() {
        var tracker = HeadphonesBatteryTracker()
        _ = tracker.connected(address: "AA:BB", level: 0.25, threshold: 0.2)
        let crossedDown = tracker.update(address: "aa-bb", level: 0.19, threshold: 0.2)
        #expect(crossedDown)
        let stillLow = tracker.update(address: "aa-bb", level: 0.18, threshold: 0.2)
        #expect(!stillLow)
        let roseAbove = tracker.update(address: "aa-bb", level: 0.3, threshold: 0.2)
        #expect(!roseAbove)
        let crossedAgain = tracker.update(address: "aa-bb", level: 0.2, threshold: 0.2)
        #expect(crossedAgain)
    }

    @Test("Первое чтение опросом без подключения в этом запуске: только запоминается")
    func firstPoll() {
        var tracker = HeadphonesBatteryTracker()
        let first = tracker.update(address: "aa-bb", level: 0.1, threshold: 0.2)
        #expect(!first)
    }
}
