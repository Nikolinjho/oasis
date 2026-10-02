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

  @Test("Одновременные Charging и Low Power отсортированы по приоритету очереди: Low Power первым")
  func simultaneousAlertsSortedByPriority() {
    let old = Self.battery(0.4)
    let new = PowerState(isPluggedIn: true, isCharging: true, level: 0.4, isLowPowerMode: true)
    #expect(PowerNotices.alerts(from: old, to: new) == [.lowPower(level: 0.4), .charging(level: 0.4)])
  }

  @Test("Battery выключен: никаких уведомлений питания")
  func disabled() {
    let rules = PowerRules(isEnabled: false)
    #expect(PowerNotices.alerts(from: Self.state(plugged: false), to: Self.state(plugged: true), rules: rules).isEmpty)
    #expect(PowerNotices.alerts(from: Self.battery(0.11), to: Self.battery(0.10), rules: rules).isEmpty)
  }

  @Test("Notify on low power mode и Warn on low battery выключают свои уведомления, Charging остаётся")
  func toggles() {
    let quiet = PowerRules(notifiesLowPower: false, warnsLowBattery: false)
    #expect(PowerNotices.alerts(from: Self.battery(0.4), to: Self.battery(0.4, lowPower: true), rules: quiet).isEmpty)
    #expect(PowerNotices.alerts(from: Self.battery(0.11), to: Self.battery(0.10), rules: quiet).isEmpty)
    #expect(
      PowerNotices.alerts(from: Self.state(plugged: false), to: Self.state(plugged: true, level: 0.8), rules: quiet)
        == [.charging(level: 0.8)])
  }

  @Test("Порог 20%: Low Battery при переходе через 20, не через 10")
  func threshold() {
    let rules = PowerRules(lowBatteryThreshold: 0.2)
    #expect(PowerNotices.alerts(from: Self.battery(0.21), to: Self.battery(0.20), rules: rules) == [.lowBattery(level: 0.20)])
    #expect(PowerNotices.alerts(from: Self.battery(0.11), to: Self.battery(0.10), rules: rules).isEmpty)
  }
}
