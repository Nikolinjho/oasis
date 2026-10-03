import Foundation
import IslandCore
import Testing

@testable import Oasis

// .serialized — по той же причине, что у AppSettingsTests: запись в домен на диске
@Suite(.serialized)
@MainActor
struct CalendarSettingsTests {
  @Test("Умолчания страницы Calendar как у Alcove 1.7.9 (ui-inspection 1.9)")
  func defaultsMatchAlcove() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let calendar = AppSettings(defaults: defaults).calendar
    #expect(calendar.isEnabled)
    #expect(calendar.leadMinutes == 15)
    #expect(calendar.sound)
    #expect(!calendar.hourlyChime)
    #expect(!calendar.useColor)
    #expect(!calendar.disableDuringEvents)
    #expect(!calendar.eventIndicators)
    #expect(!calendar.monthView)
    #expect(calendar.quickPeek)
    #expect(!calendar.peekBeforeStart)
    #expect(calendar.peekOnStart)
    #expect(calendar.peekDuration == 4)
    #expect(calendar.coloredIndicator)
    #expect(calendar.excluded.isEmpty)
    #expect(calendar.modes.isEmpty)
    #expect(calendar.filter == CalendarFilter())
  }

  @Test("Настройки Calendar переживают перезапуск, каждое изменение зовёт onChange настроек")
  func persists() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    var calls = 0
    settings.onChange = { calls += 1 }
    let calendar = settings.calendar
    calendar.isEnabled = false
    calendar.leadMinutes = 25
    calendar.sound = false
    calendar.hourlyChime = true
    calendar.useColor = true
    calendar.disableDuringEvents = true
    calendar.eventIndicators = true
    calendar.monthView = true
    calendar.quickPeek = false
    calendar.peekBeforeStart = true
    calendar.peekOnStart = false
    calendar.peekDuration = 6
    calendar.coloredIndicator = false
    calendar.excluded = ["home"]
    calendar.modes = ["work": .liveActivity]
    // то же значение ещё раз — без onChange
    calendar.leadMinutes = 25
    #expect(calls == 15)

    let again = AppSettings(defaults: defaults).calendar
    #expect(!again.isEnabled)
    #expect(again.leadMinutes == 25)
    #expect(!again.sound)
    #expect(again.hourlyChime)
    #expect(again.useColor)
    #expect(again.disableDuringEvents)
    #expect(again.eventIndicators)
    #expect(again.monthView)
    #expect(!again.quickPeek)
    #expect(again.peekBeforeStart)
    #expect(!again.peekOnStart)
    #expect(again.peekDuration == 6)
    #expect(!again.coloredIndicator)
    #expect(again.excluded == ["home"])
    #expect(again.modes == ["work": .liveActivity])
    #expect(again.filter == CalendarFilter(isEnabled: false, excluded: ["home"], modes: ["work": .liveActivity]))
  }

  @Test("Чекбокс и меню режима календаря: Both не хранится, выключение — в excluded")
  func calendarRows() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let calendar = AppSettings(defaults: defaults).calendar
    calendar.setIncluded(false, "home")
    #expect(!calendar.isIncluded("home"))
    calendar.setIncluded(true, "home")
    #expect(calendar.isIncluded("home"))
    calendar.setMode(.expandedView, "work")
    #expect(calendar.modes == ["work": .expandedView])
    calendar.setMode(.both, "work")
    #expect(calendar.modes.isEmpty)
  }

  @Test("Значения из UserDefaults вне диапазона зажимаются: Time before event 5…30, Peek duration 1…6")
  func clamped() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    defaults.set(90.0, forKey: CalendarSettings.Key.leadMinutes)
    defaults.set(0.0, forKey: CalendarSettings.Key.peekDuration)
    defaults.set(["work": "nonsense", "home": "liveActivity"], forKey: CalendarSettings.Key.modes)
    let calendar = AppSettings(defaults: defaults).calendar
    #expect(calendar.lead == 30 * 60)
    #expect(calendar.peekSeconds == 1)
    #expect(calendar.modes == ["home": .liveActivity])
  }
}
