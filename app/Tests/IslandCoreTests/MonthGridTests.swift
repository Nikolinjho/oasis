import Foundation
import Testing

@testable import IslandCore

/// Always show month view: сетка месяца с понедельника (осмотр Alcove 03.10)
struct MonthGridTests {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    // системная неделя может начинаться с воскресенья: сетка всё равно с понедельника
    calendar.firstWeekday = 1
    return calendar
  }

  static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  static func numbers(_ grid: MonthGrid) -> [[Int?]] {
    grid.weeks.map { $0.map { $0.map { calendar.component(.day, from: $0) } } }
  }

  @Test("Октябрь 2026: 1-е — четверг, три пустые клетки, пять недель, заголовок OCT")
  func october() {
    let grid = MonthGrid(containing: Self.date(2026, 10, 3), calendar: Self.calendar)
    #expect(grid.title == "OCT")
    #expect(grid.leadingBlanks == 3)
    #expect(grid.days.count == 31)
    #expect(Self.numbers(grid).first == [nil, nil, nil, 1, 2, 3, 4])
    #expect(Self.numbers(grid).last == [26, 27, 28, 29, 30, 31, nil])
    #expect(grid.weeks.count == 5)
    #expect(grid.days.first == Self.calendar.startOfDay(for: Self.date(2026, 10, 1)))
  }

  @Test("Февраль 2026, невисокосный: 28 дней с воскресенья — шесть пустых клеток")
  func february() {
    let grid = MonthGrid(containing: Self.date(2026, 2, 14), calendar: Self.calendar)
    #expect(grid.title == "FEB")
    #expect(grid.days.count == 28)
    #expect(grid.leadingBlanks == 6)
    #expect(grid.weeks.count == 5)
  }

  @Test("Август 2026: начинается в субботу — шесть недель")
  func sixWeeks() {
    let grid = MonthGrid(containing: Self.date(2026, 8, 20), calendar: Self.calendar)
    #expect(grid.leadingBlanks == 5)
    #expect(grid.weeks.count == 6)
    #expect(Self.numbers(grid).last == [31, nil, nil, nil, nil, nil, nil])
  }

  @Test("Выходные — суббота и воскресенье, колонки 5 и 6")
  func weekend() {
    #expect(MonthGrid.weekdaySymbols == ["M", "T", "W", "T", "F", "S", "S"])
    #expect(MonthGrid.isWeekend(column: 5) && MonthGrid.isWeekend(column: 6))
    #expect(!MonthGrid.isWeekend(column: 4))
  }

  static func event(_ id: String, calendar: String, _ start: Date, hours: Double = 1, allDay: Bool = false, color: RGB) -> CalendarEvent {
    CalendarEvent(
      id: id, title: id, start: start, end: start.addingTimeInterval(hours * 3600), isAllDay: allDay, color: color,
      calendarID: calendar)
  }

  @Test("Индикаторы дня: по одной черточке на календарь с событиями в этот день, не больше трёх, в цвете календаря")
  func indicators() {
    let blue = RGB(red: 0, green: 0.5, blue: 1)
    let green = RGB(red: 0, green: 0.8, blue: 0.3)
    let red = RGB(red: 1, green: 0, blue: 0)
    let gray = RGB(red: 0.5, green: 0.5, blue: 0.5)
    let day = Self.date(2026, 10, 5, 0)
    let events = [
      Self.event("a", calendar: "work", Self.date(2026, 10, 5, 9), color: blue),
      Self.event("b", calendar: "work", Self.date(2026, 10, 5, 11), color: blue),
      Self.event("c", calendar: "home", Self.date(2026, 10, 5, 18), color: green),
      Self.event("d", calendar: "gym", Self.date(2026, 10, 5, 20), color: red),
      Self.event("e", calendar: "misc", Self.date(2026, 10, 5, 21), color: gray),
      Self.event("next", calendar: "misc", Self.date(2026, 10, 6, 9), color: gray),
    ]
    #expect(MonthGrid.indicators(on: day, events: events, calendar: Self.calendar) == [blue, green, red])
    #expect(MonthGrid.indicators(on: Self.date(2026, 10, 7), events: events, calendar: Self.calendar).isEmpty)
    // событие на весь день, заканчивающееся в полночь следующего, на следующий день не попадает
    let holiday = Self.event("h", calendar: "holidays", Self.date(2026, 10, 5, 0), hours: 24, allDay: true, color: blue)
    #expect(MonthGrid.indicators(on: Self.date(2026, 10, 6), events: [holiday], calendar: Self.calendar).isEmpty)
  }
}
