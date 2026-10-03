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
}
