import Testing
@testable import IslandCore

struct PowerNoticesTests {
    static func state(plugged: Bool, level: Double = 0.51) -> PowerState {
        PowerState(isPluggedIn: plugged, isCharging: plugged, level: level, isLowPowerMode: false)
    }

    @Test("Первое состояние после запуска ничего не показывает")
    func firstStateIsSilent() {
        #expect(PowerNotices.alerts(from: nil, to: Self.state(plugged: true)).isEmpty)
    }

    @Test("Подключение питания показывает Charging с уровнем")
    func plugIn() {
        #expect(PowerNotices.alerts(from: Self.state(plugged: false), to: Self.state(plugged: true, level: 0.8)) == [.charging(level: 0.8)])
    }

    @Test("Смена уровня и отключение питания ничего не показывают")
    func otherChangesAreSilent() {
        #expect(PowerNotices.alerts(from: Self.state(plugged: true, level: 0.5), to: Self.state(plugged: true, level: 0.6)).isEmpty)
        #expect(PowerNotices.alerts(from: Self.state(plugged: true), to: Self.state(plugged: false)).isEmpty)
    }
}
