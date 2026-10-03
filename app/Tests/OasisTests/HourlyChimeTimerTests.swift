import Foundation
import IslandCore
import Testing

@testable import Oasis

@MainActor
struct HourlyChimeTimerTests {
  @Test("Выключен — таймера нет; включён — ждёт ближайшее начало часа")
  func schedulesOnlyWhenEnabled() {
    let timer = HourlyChimeTimer {}
    #expect(timer.target == nil)
    timer.isEnabled = true
    #expect(timer.target == HourlyChime.next(after: Date()))
    timer.isEnabled = false
    #expect(timer.target == nil)
  }

  @Test("Главный тумблер Calendar и Play hourly chime вместе включают часы-куранты через CalendarBridge")
  func bridgeEnablesChime() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    let bridge = CalendarBridge(store: IslandStore(config: .alcove), settings: settings.calendar)
    #expect(!bridge.chime.isEnabled)
    settings.calendar.hourlyChime = true
    bridge.apply()
    #expect(bridge.chime.isEnabled)
    settings.calendar.isEnabled = false
    bridge.apply()
    #expect(!bridge.chime.isEnabled)
  }
}
