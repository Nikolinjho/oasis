import Foundation
import Testing

@testable import IslandSources

/// Сколько событий грузит источник: месяц целиком для сетки и неделя вперёд для ближайшего дня
struct CalendarRangeTests {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return calendar
  }

  static func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
  }

  @Test("Начало месяца — с 1-го числа до конца месяца: неделя вперёд в нём уже есть")
  func earlyMonth() {
    let range = EventKitCalendarSource.range(now: Self.date(10, 3, 13), calendar: Self.calendar)
    #expect(range.start == Self.date(10, 1))
    #expect(range.end == Self.date(11, 1))
  }

  @Test("Конец месяца — до начала восьмого дня вперёд, уже в следующем месяце")
  func lateMonth() {
    let range = EventKitCalendarSource.range(now: Self.date(10, 29, 13), calendar: Self.calendar)
    #expect(range.start == Self.date(10, 1))
    #expect(range.end == Self.date(11, 6))
  }
}
