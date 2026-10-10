import Foundation

public enum SoonSchedule {
  public static func dueIDs(_ reminders: [SoonReminder], now: Date) -> Set<String> {
    Set(reminders.filter { $0.state != .completed && ($0.state == .due || $0.dueAt <= now) }.map(\.occurrenceID))
  }

  public static func nearestFuture(_ reminders: [SoonReminder], now: Date) -> SoonReminder? {
    sorted(reminders, now: now).first { $0.state == .scheduled && $0.dueAt > now }
  }

  public static func sorted(
    _ reminders: [SoonReminder], now: Date, includeCompleted: Bool = false
  ) -> [SoonReminder] {
    reminders.filter { includeCompleted || $0.state != .completed }.sorted { left, right in
      let leftRank = rank(left, now: now)
      let rightRank = rank(right, now: now)
      if leftRank != rightRank { return leftRank < rightRank }
      if left.dueAt != right.dueAt { return left.dueAt < right.dueAt }
      return left.id.uuidString < right.id.uuidString
    }
  }

  private static func rank(_ reminder: SoonReminder, now: Date) -> Int {
    if reminder.state == .completed { return 2 }
    return reminder.state == .due || reminder.dueAt <= now ? 0 : 1
  }
}
