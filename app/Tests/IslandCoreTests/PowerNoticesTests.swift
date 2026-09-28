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

    static func battery(_ level: Double, plugged: Bool = false, lowPower: Bool = false) -> PowerState {
        PowerState(isPluggedIn: plugged, isCharging: plugged, level: level, isLowPowerMode: lowPower)
    }

    @Test("Заряд опустился до 10% без питания: Low Battery один раз")
    func lowBattery() {
        #expect(PowerNotices.alerts(from: Self.battery(0.11), to: Self.battery(0.10)) == [.lowBattery(level: 0.10)])
        #expect(PowerNotices.alerts(from: Self.battery(0.10), to: Self.battery(0.09)).isEmpty)
        #expect(PowerNotices.alerts(from: Self.battery(0.11, plugged: true), to: Self.battery(0.10, plugged: true)).isEmpty)
    }

    @Test("Режим энергосбережения включился: Low Power с уровнем, выключение молчит")
    func lowPower() {
        #expect(PowerNotices.alerts(from: Self.battery(0.4), to: Self.battery(0.4, lowPower: true)) == [.lowPower(level: 0.4)])
        #expect(PowerNotices.alerts(from: Self.battery(0.4, lowPower: true), to: Self.battery(0.4)).isEmpty)
    }
}
