import Foundation

/// Чистые расчёты по наблюдаемой истории. Календарь и текущее время передаёт вызывающий код.
public enum LimitForecast {
  /// Ориентир равномерного расхода недели, п.п. в день.
  public static let dailyBudget = 100.0 / 7
  public static let minSpan: TimeInterval = 20 * 60
  public static let minSpent = 2.0
  public static let sessionSpan: TimeInterval = 30 * 60
  public static let minSessionSpan: TimeInterval = 10 * 60
  public static let maxSampleAge: TimeInterval = 30 * 60

  public enum Horizon: Equatable, Sendable {
    case midnight
    /// Локальное время конца рабочего дня в минутах. После него горизонт — полночь.
    case workdayEnd(minutes: Int)
  }

  public struct Day: Equatable, Sendable {
    /// Наблюдаемый расход сегодня, п.п. Первый замер без предыдущего — исходная точка.
    public var spent: Double
    public var projected: Double?
    public var weekRunsOutAt: Date?

    public init(spent: Double, projected: Double?, weekRunsOutAt: Date?) {
      self.spent = spent
      self.projected = projected
      self.weekRunsOutAt = weekRunsOutAt
    }
  }

  public static func horizonDate(_ horizon: Horizon, now: Date, calendar: Calendar) -> Date {
    let start = calendar.startOfDay(for: now)
    let midnight = calendar.date(byAdding: .day, value: 1, to: start) ?? now
    guard case .workdayEnd(let minutes) = horizon else { return midnight }
    let bounded = min(max(minutes, 0), 23 * 60 + 59)
    let end = calendar.date(bySettingHour: bounded / 60, minute: bounded % 60, second: 0, of: start) ?? midnight
    return now < end ? end : midnight
  }

  public static func day(history: [ClaudeLimits], now: Date, horizon: Horizon, calendar: Calendar) -> Day? {
    let samples = history.filter { $0.capturedAt <= now }.sorted { $0.capturedAt < $1.capturedAt }
    let start = calendar.startOfDay(for: now)
    guard let last = samples.last, let week = last.sevenDay,
      now.timeIntervalSince(last.capturedAt) <= maxSampleAge, now < week.resetsAt,
      let first = samples.firstIndex(where: { $0.capturedAt >= start && $0.sevenDay != nil })
    else { return nil }

    var spent = 0.0
    var forecastSpent = 0.0
    // Снимок до полуночи задаёт базу. Пропуск окна разрывает наблюдение, а не подставляет 0%.
    let base = max(first - 1, 0)
    for index in samples.indices.dropFirst(base + 1) {
      guard let previous = samples[index - 1].sevenDay, let current = samples[index].sevenDay,
        samples[index].capturedAt < current.resetsAt
      else { continue }
      let delta =
        ClaudeWindow.sameWindow(previous.resetsAt, current.resetsAt)
        ? boundedUsed(current) - boundedUsed(previous) : boundedUsed(current)
      let increase = Double(max(delta, 0))
      spent += increase
      // Прирост от вчерашней базы входит в расход дня, но не в темп короткого сегодняшнего отрезка.
      if index > first { forecastSpent += increase }
    }

    let elapsed = last.capturedAt.timeIntervalSince(samples[first].capturedAt)
    guard elapsed >= minSpan, forecastSpent >= minSpent else {
      return Day(spent: spent, projected: nil, weekRunsOutAt: nil)
    }
    let rate = forecastSpent / elapsed
    let left = max(horizonDate(horizon, now: now, calendar: calendar).timeIntervalSince(last.capturedAt), 0)
    let runsOut = last.capturedAt.addingTimeInterval(Double(100 - boundedUsed(week)) / rate)
    return Day(
      spent: spent, projected: spent + rate * left,
      weekRunsOutAt: runsOut > now && runsOut < week.resetsAt ? runsOut : nil)
  }

  public static func sessionRunsOutAt(history: [ClaudeLimits], now: Date) -> Date? {
    let recent = history.filter {
      $0.capturedAt <= now && $0.capturedAt >= now.addingTimeInterval(-sessionSpan)
    }.sorted { $0.capturedAt < $1.capturedAt }
    guard let last = recent.last, let window = last.fiveHour, now < window.resetsAt,
      now.timeIntervalSince(last.capturedAt) <= maxSampleAge
    else { return nil }
    // Используем непрерывный хвост текущего окна: отсутствие окна не становится замером 0%.
    let sameWindow = recent.reversed().prefix { sample in
      guard let five = sample.fiveHour else { return false }
      return ClaudeWindow.sameWindow(five.resetsAt, window.resetsAt)
    }
    guard let first = sameWindow.last, let start = first.fiveHour else { return nil }
    let span = last.capturedAt.timeIntervalSince(first.capturedAt)
    let delta = Double(boundedUsed(window) - boundedUsed(start))
    guard span >= minSessionSpan, delta >= 1 else { return nil }
    let runsOut = last.capturedAt.addingTimeInterval(Double(100 - boundedUsed(window)) / (delta / span))
    return runsOut > now && runsOut < window.resetsAt ? runsOut : nil
  }

  private static func boundedUsed(_ window: ClaudeWindow) -> Int {
    min(max(window.usedPercent, 0), 100)
  }
}
