import Foundation

/// Play hourly chime (Calendar, ui-inspection 1.9): звук `chime` в начале каждого часа
public enum HourlyChime {
  /// Сколько таймер может опоздать: дольше — Mac спал, звонить уже поздно
  public static let tolerance: TimeInterval = 5

  /// Ближайшее начало часа строго после date
  public static func next(after date: Date, calendar: Calendar = .current) -> Date {
    calendar.nextDate(
      after: date, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime)
      ?? date.addingTimeInterval(3600)
  }

  public static func isOnTime(fired: Date, target: Date) -> Bool {
    abs(fired.timeIntervalSince(target)) <= tolerance
  }
}
