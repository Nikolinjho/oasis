import Foundation
import Testing

@testable import IslandCore

/// Правая колонка календарного вида без сетки месяца: ближайший день с событиями (осмотр Alcove 03.10)
struct NearestDayTests {
  static let calendar = MonthGridTests.calendar
  static func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date { MonthGridTests.date(2026, month, day, hour) }
  static let color = RGB(red: 0.5, green: 0.7, blue: 0.9)

  static func event(_ id: String, _ start: Date, hours: Double = 1, allDay: Bool = false) -> CalendarEvent {
    CalendarEvent(id: id, title: id, start: start, end: start.addingTimeInterval(hours * 3600), isAllDay: allDay, color: Self.color)
  }

  /// Суббота, 3 октября 2026, 13:00
  static let now = date(10, 3, 13)

  @Test("Завтра пусто, в понедельник события — колонка понедельника: весь день сверху, остальные по началу")
  func skipsEmptyTomorrow() throws {
    let holiday = Self.event("День учителя", Self.date(10, 5, 0), hours: 24, allDay: true)
    let gym = Self.event("Зал", Self.date(10, 5, 8))
    let daily = Self.event("Team daily", Self.date(10, 5, 11))
    let today = Self.event("Сегодня", Self.date(10, 3, 14))
    let agenda = DayAgenda.make(events: [daily, gym, holiday, today], now: Self.now, calendar: Self.calendar)
    let nearest = try #require(agenda.nearestDay(after: Self.now, calendar: Self.calendar))
    #expect(nearest.day == Self.calendar.startOfDay(for: Self.date(10, 5)))
    #expect(nearest.events.map(\.id) == ["День учителя", "Зал", "Team daily"])
    #expect(DayAgenda.title(for: nearest.day, now: Self.now, calendar: Self.calendar) == "MON, 5")
  }

  @Test("Завтра — заголовок TMRW")
  func tomorrowTitle() {
    #expect(DayAgenda.title(for: Self.date(10, 4, 0), now: Self.now, calendar: Self.calendar) == "TMRW")
  }

  @Test("Событий нет 7 дней — ближайшего дня нет; на 7-й день — есть, на 8-й — нет")
  func withinSevenDays() {
    let day7 = DayAgenda.make(events: [Self.event("7", Self.date(10, 10, 9))], now: Self.now, calendar: Self.calendar)
    #expect(day7.nearestDay(after: Self.now, calendar: Self.calendar)?.events.map(\.id) == ["7"])
    let day8 = DayAgenda.make(events: [Self.event("8", Self.date(10, 11, 9))], now: Self.now, calendar: Self.calendar)
    #expect(day8.nearestDay(after: Self.now, calendar: Self.calendar) == nil)
    #expect(DayAgenda.empty.nearestDay(after: Self.now, calendar: Self.calendar) == nil)
  }

  @Test("Повестка, собранная из today и tomorrow, без всего диапазона: ближайший день — завтра")
  func legacyAgenda() {
    let tomorrow = Self.event("Зал", Self.date(10, 4, 10))
    let agenda = DayAgenda(today: [], tomorrow: [tomorrow])
    #expect(agenda.nearestDay(after: Self.now, calendar: Self.calendar)?.events == [tomorrow])
  }
}
