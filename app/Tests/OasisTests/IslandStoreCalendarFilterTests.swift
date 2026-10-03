import Foundation
import IslandCore
import Testing

@testable import Oasis

/// Страница Calendar → Calendars: store делит события на повестку раскрытого и live-повестку часов
@MainActor
struct IslandStoreCalendarFilterTests {
  static func event(_ id: String, calendar: String, now: Date) -> CalendarEvent {
    CalendarEvent(
      id: id, title: id, start: now.addingTimeInterval(60), end: now.addingTimeInterval(120),
      isAllDay: false, color: RGB(red: 1, green: 0, blue: 0), calendarID: calendar)
  }

  @Test("Live Activity — только в повестке часов, Expanded View — только в раскрытом; смена фильтра — сразу")
  func splitsAgendas() {
    let store = IslandStore()
    let now = Date()
    var live: [[String]] = []
    store.onAgendaChange = { live.append($0.today.map(\.id)) }
    store.apply(
      events: [Self.event("work", calendar: "work", now: now), Self.event("home", calendar: "home", now: now)], now: now)
    #expect(store.agenda.today.map(\.id) == ["work", "home"])

    store.setCalendarFilter(CalendarFilter(modes: ["work": .liveActivity, "home": .expandedView]), now: now)
    #expect(store.agenda.today.map(\.id) == ["home"])
    #expect(live.last == ["work"])

    // тот же фильтр ещё раз — без лишней пересборки
    let count = live.count
    store.setCalendarFilter(CalendarFilter(modes: ["work": .liveActivity, "home": .expandedView]), now: now)
    #expect(live.count == count)
  }

  @Test("Главный тумблер выключен — пусто и в раскрытом, и у часов; отладочная повестка тоже фильтруется")
  func disabledEmptiesEverything() {
    let store = IslandStore()
    let now = Date()
    var live: [[String]] = []
    store.onAgendaChange = { live.append($0.today.map(\.id)) }
    store.setCalendarFilter(CalendarFilter(isEnabled: false), now: now)
    store.pinDebugEvents([Self.event("fake", calendar: "work", now: now)], now: now)
    #expect(store.agenda.today.isEmpty)
    #expect(live.last == [])
  }
}
