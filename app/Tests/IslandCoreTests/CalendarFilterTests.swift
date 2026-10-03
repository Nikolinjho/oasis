import Foundation
import Testing

@testable import IslandCore

struct CalendarFilterTests {
  static let start = Date(timeIntervalSince1970: 1_800_000_000)

  static func event(_ id: String, calendar: String?) -> CalendarEvent {
    CalendarEvent(
      id: id, title: id, start: start, end: start.addingTimeInterval(600), isAllDay: false,
      color: RGB(red: 0.2, green: 0.5, blue: 1), calendarID: calendar)
  }

  static let work = event("work", calendar: "work")
  static let home = event("home", calendar: "home")
  static let birthdays = event("birthdays", calendar: "birthdays")
  /// Отладочное событие без календаря: его не фильтруем, иначе отладка зависела бы от настроек
  static let debug = event("debug", calendar: nil)
  static let all = [work, home, birthdays, debug]

  @Test("По умолчанию все календари в режиме Both: события идут и в live, и в раскрытый")
  func defaultsShowEverything() {
    let filter = CalendarFilter()
    #expect(filter.live(Self.all) == Self.all)
    #expect(filter.expanded(Self.all) == Self.all)
    #expect(filter.mode(for: "new") == .both)
  }

  @Test("Live Activity — только компакт, peek и напоминания; Expanded View — только раскрытый")
  func modes() {
    let filter = CalendarFilter(modes: ["work": .liveActivity, "home": .expandedView])
    #expect(filter.live(Self.all) == [Self.work, Self.birthdays, Self.debug])
    #expect(filter.expanded(Self.all) == [Self.home, Self.birthdays, Self.debug])
  }

  @Test("Выключенный календарь не попадает никуда, какой бы ни был режим")
  func excluded() {
    let filter = CalendarFilter(excluded: ["birthdays", "work"], modes: ["work": .liveActivity])
    #expect(filter.live(Self.all) == [Self.home, Self.debug])
    #expect(filter.expanded(Self.all) == [Self.home, Self.debug])
  }

  @Test("Главный тумблер Calendar выключен — событий нет ни в live, ни в раскрытом")
  func disabled() {
    let filter = CalendarFilter(isEnabled: false)
    #expect(filter.live(Self.all).isEmpty)
    #expect(filter.expanded(Self.all).isEmpty)
  }

  @Test("Событие окна из календаря Live Activity не становится карточкой Duo: его нет в повестке раскрытого")
  func liveOnlyEventStaysOutOfDuo() {
    let agenda = DayAgenda.make(events: [Self.home], now: Self.start.addingTimeInterval(-60))
    let now = Self.start.addingTimeInterval(-30)
    #expect(agenda.current(at: now, live: Self.work) == Self.home)
    #expect(agenda.upcoming(at: now, live: Self.work) == [Self.home])
    // отладочное событие без календаря — как раньше, карточкой
    #expect(agenda.current(at: now, live: Self.debug) == Self.debug)
  }
}
