import Foundation

/// Сетка месяца календарного вида (Always show month view, осмотр Alcove 03.10): неделя с понедельника,
/// пустые клетки до 1-го и после последнего дня
public struct MonthGrid: Equatable, Sendable {
  /// «OCT»: заголовок месяца, английские сокращения, как у Alcove
  public let title: String
  /// Начала дней месяца по порядку
  public let days: [Date]
  /// Пустые клетки перед 1-м числом: сколько дней от понедельника
  public let leadingBlanks: Int

  public static let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]
  /// Сколько черточек под числом максимум
  public static let maxIndicators = 3

  public init(containing date: Date, calendar: Calendar = .current) {
    let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
    days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    // weekday: 1 — воскресенье … 7 — суббота, от firstWeekday не зависит
    leadingBlanks = (calendar.component(.weekday, from: start) + 5) % 7
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "MMM"
    title = formatter.string(from: start).uppercased()
  }

  /// Недели по 7 клеток, nil — пустая клетка
  public var weeks: [[Date?]] {
    var cells: [Date?] = Array(repeating: nil, count: leadingBlanks) + days.map { $0 }
    cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
    return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
  }

  /// Суббота и воскресенье — серые
  public static func isWeekend(column: Int) -> Bool { column >= 5 }

  /// Use event indicators: цвета календарей с событиями в этот день, по одному на календарь, в порядке событий.
  /// Календарь — calendarID, у события без него — свой цвет
  public static func indicators(on day: Date, events: [CalendarEvent], calendar: Calendar = .current) -> [RGB] {
    let start = calendar.startOfDay(for: day)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
    var seen: Set<String> = []
    var colors: [RGB] = []
    for event in events where event.start < end && event.end > start {
      let key = event.calendarID ?? "\(event.color)"
      guard seen.insert(key).inserted else { continue }
      colors.append(event.color)
      if colors.count == maxIndicators { break }
    }
    return colors
  }
}
