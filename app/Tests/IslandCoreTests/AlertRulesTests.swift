import Testing
@testable import IslandCore

struct AlertRulesTests {
    static let airpods = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 0.8))
    static let reminder = IslandAlert.calendarReminder(
        CalendarReminder(eventID: "e", title: "Sync", minutes: 5, color: RGB(red: 1, green: 0, blue: 0)))

    @Test("По умолчанию как у Alcove: 5 с у батареи и наушников, напоминание — 4.2 с, звуки как у вида")
    func defaults() {
        let rules = AlertRules()
        #expect(rules.duration(for: .charging(level: 0.5)) == .seconds(5))
        #expect(rules.duration(for: Self.airpods) == .seconds(5))
        #expect(rules.duration(for: Self.reminder) == IslandTiming.calendarPeek)
        #expect(rules.sound(for: .lowBattery(level: 0.1)) == .lowBattery)
        #expect(rules.sound(for: .lowPower(level: 0.4)) == .lowPower)
        #expect(rules.sound(for: Self.reminder) == .event)
    }

    @Test("Duration Battery и Connectivity раздельно")
    func durations() {
        var rules = AlertRules()
        rules.batteryDuration = .seconds(3)
        rules.connectivityDuration = .milliseconds(2500)
        #expect(rules.duration(for: .lowPower(level: 0.4)) == .seconds(3))
        #expect(rules.duration(for: Self.airpods) == .milliseconds(2500))
    }

    @Test("Play sound on low battery выключен: Low Battery без звука, Low Power звучит")
    func lowBatterySound() {
        var rules = AlertRules()
        rules.lowBatterySound = false
        #expect(rules.sound(for: .lowBattery(level: 0.1)) == nil)
        #expect(rules.sound(for: .lowPower(level: 0.4)) == .lowPower)
    }

    @Test("Низкий заряд наушников звучит low-battery, Play sound on low battery Connectivity его гасит")
    func headphonesSound() {
        let low = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 0.15, isLowBattery: true))
        #expect(low.sound == .lowBattery)
        #expect(Self.airpods.sound == nil)
        var rules = AlertRules()
        #expect(rules.sound(for: low) == .lowBattery)
        rules.headphonesLowBatterySound = false
        #expect(rules.sound(for: low) == nil)
    }
}
