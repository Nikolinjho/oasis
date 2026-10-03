import Foundation
import Testing

@testable import IslandCore

/// Play hourly chime: звук в начале каждого часа (ui-inspection 1.9, вживую не проверено)
struct HourlyChimeTests {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return calendar
  }

  static func date(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: hour, minute: minute, second: second))!
  }

  @Test("Следующий час — минута 0 после даты; ровно в начале часа — уже следующий")
  func nextHour() {
    #expect(HourlyChime.next(after: Self.date(13, 21, 5), calendar: Self.calendar) == Self.date(14, 0))
    #expect(HourlyChime.next(after: Self.date(13, 59, 59), calendar: Self.calendar) == Self.date(14, 0))
    #expect(HourlyChime.next(after: Self.date(14, 0), calendar: Self.calendar) == Self.date(15, 0))
    #expect(HourlyChime.next(after: Self.date(23, 30), calendar: Self.calendar) == Self.date(23, 30).addingTimeInterval(1800))
  }

  @Test("Таймер, проснувшийся сильно позже часа (Mac спал), не звонит")
  func lateFire() {
    #expect(HourlyChime.isOnTime(fired: Self.date(14, 0, 1), target: Self.date(14, 0)))
    #expect(!HourlyChime.isOnTime(fired: Self.date(14, 7), target: Self.date(14, 0)))
  }
}
