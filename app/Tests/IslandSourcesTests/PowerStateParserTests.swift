import IOKit.ps
import Testing

@testable import IslandSources

struct PowerStateParserTests {
  static func battery(state: String, current: Int, max: Int, charging: Bool) -> [String: Any] {
    [
      kIOPSTypeKey: kIOPSInternalBatteryType,
      kIOPSPowerSourceStateKey: state,
      kIOPSCurrentCapacityKey: current,
      kIOPSMaxCapacityKey: max,
      kIOPSIsChargingKey: charging,
    ]
  }

  @Test("Встроенная батарея от сети: подключено, уровень current / max")
  func pluggedIn() throws {
    let state = try #require(
      PowerStateParser.parse(
        descriptions: [Self.battery(state: kIOPSACPowerValue, current: 51, max: 100, charging: true)],
        isLowPowerMode: false))
    #expect(state.isPluggedIn)
    #expect(state.isCharging)
    #expect(state.level == 0.51)
  }

  @Test("От батареи: не подключено, режим энергосбережения передаётся как есть")
  func onBattery() throws {
    let state = try #require(
      PowerStateParser.parse(
        descriptions: [Self.battery(state: kIOPSBatteryPowerValue, current: 30, max: 60, charging: false)],
        isLowPowerMode: true))
    #expect(!state.isPluggedIn)
    #expect(state.level == 0.5)
    #expect(state.isLowPowerMode)
  }

  @Test("Без встроенной батареи состояния нет")
  func noBattery() {
    #expect(PowerStateParser.parse(descriptions: [[kIOPSTypeKey: "UPS"]], isLowPowerMode: false) == nil)
  }
}
