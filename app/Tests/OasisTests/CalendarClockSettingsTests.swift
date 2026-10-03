import Foundation
import IslandCore
import Testing

@testable import Oasis

/// Страница Calendar меняет часы на лету: Time before event, Before event starts, разные повестки live и раскрытого
@MainActor
struct CalendarClockSettingsTests {
  static let start = CalendarClockTests.start
  static let event = CalendarClockTests.event
  static let agenda = CalendarClockTests.agenda

  static func at(_ offset: TimeInterval) -> Date { start.addingTimeInterval(offset) }

  @Test("Time before event 30 минут: окно открывается за 30 минут, смена настройки применяется сразу")
  func leadAppliesOnTheFly() {
    let store = IslandStore(config: .alcove)
    let clock = CalendarClock(store: store, start: Self.at(-2000))
    clock.update(agenda: Self.agenda, now: Self.at(-1700))
    #expect(!store.model.calendarLive)
    clock.apply(CalendarClock.Settings(lead: 30 * 60), now: Self.at(-1700))
    #expect(store.model.calendarLive)
    clock.apply(CalendarClock.Settings(lead: 5 * 60), now: Self.at(-1700))
    #expect(!store.model.calendarLive)
  }

  @Test("Before event starts: напоминание в начале окна, за Time before event")
  func reminderAtWindowStart() {
    let store = IslandStore(config: .alcove)
    let clock = CalendarClock(store: store, start: Self.at(-301), settings: .init(lead: 5 * 60, remindsBeforeStart: true))
    clock.update(agenda: Self.agenda, now: Self.at(-300))
    let reminder = CalendarReminder(eventID: "call", title: "Созвон", minutes: 5, color: Self.event.color)
    #expect((store.model.pending ?? store.model.surface) == .alert(.calendarReminder(reminder)))
  }

  @Test("Меню — по повестке раскрытого: событие только для Live Activity в меню не попадает")
  func menuUsesExpandedAgenda() {
    let store = IslandStore(config: .alcove)
    let clock = CalendarClock(store: store, start: Self.at(-60))
    clock.update(live: Self.agenda, expanded: .empty, now: Self.at(-60))
    #expect(store.model.calendarLive)
    #expect(clock.menuModel(now: Self.at(-60)) == nil)

    clock.update(live: .empty, expanded: Self.agenda, now: Self.at(-60))
    #expect(!store.model.calendarLive)
    #expect(clock.menuModel(now: Self.at(-60))?.event == Self.event)
  }

  @Test("Окно меню тоже по Time before event")
  func menuUsesLead() {
    let store = IslandStore(config: .alcove)
    let clock = CalendarClock(store: store, start: Self.at(-1700), settings: .init(lead: 30 * 60))
    clock.update(agenda: Self.agenda, now: Self.at(-1700))
    #expect(clock.menuModel(now: Self.at(-1700))?.event == Self.event)
  }

  @Test("Use colored calendar indicator выкл: полоска напоминания красная, а не в цвете календаря")
  func reminderIndicatorColor() {
    let store = IslandStore(config: .alcove)
    let settings = CalendarClock.Settings(remindsBeforeStart: true, coloredIndicator: false)
    let clock = CalendarClock(store: store, start: Self.at(-901), settings: settings)
    clock.update(agenda: Self.agenda, now: Self.at(-900))
    let reminder = CalendarReminder(eventID: "call", title: "Созвон", minutes: 15, color: ActivityLayouts.calendarRed)
    #expect((store.model.pending ?? store.model.surface) == .alert(.calendarReminder(reminder)))
  }

  @Test("Disable activity during events: peek на старте показывается, после него компакта нет — покой")
  func hiddenDuringEvent() {
    let store = IslandStore(config: .alcove)
    let clock = CalendarClock(store: store, start: Self.at(-60), settings: .init(hidingAfterStart: 4.2))
    clock.update(agenda: Self.agenda, now: Self.at(-60))
    #expect(store.model.surface == .calendar)
    clock.tick(now: Self.at(0))
    #expect(store.model.surface == .calendarPeek)
    clock.tick(now: Self.at(4.2))
    #expect(!store.model.calendarLive)
    #expect(store.model.surface == .idle)
    // пункты меню по идущему событию остаются: тумблер убирает только активность
    #expect(clock.menuModel(now: Self.at(10))?.event == Self.event)
  }

  @Test("Настройка: Disable activity during events держит компакт на время peek, без peek на старте — ноль")
  func hidingSettings() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let calendar = AppSettings(defaults: defaults).calendar
    #expect(calendar.clockSettings.hidingAfterStart == nil)
    calendar.disableDuringEvents = true
    #expect(calendar.clockSettings.hidingAfterStart == calendar.rules.peekInterval)
    #expect(abs((calendar.clockSettings.hidingAfterStart ?? 0) - 4.2) < 1e-9)
    calendar.peekOnStart = false
    #expect(calendar.clockSettings.hidingAfterStart == 0)
  }
}
