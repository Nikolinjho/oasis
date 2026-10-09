import Foundation

/// Что показывает вид Claude Code на момент now: снимок, прогноз дня и тексты. Чистые строки, чтобы проверять тестами
public struct ClaudePanel: Equatable, Sendable {
  /// Старше 30 минут — «данные устарели», прогноз скрыт (спека модуля)
  public static let staleAfter: TimeInterval = 30 * 60
  static let weekdays = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]

  public var limits: ClaudeLimits
  public var day: LimitForecast.Day?
  public var now: Date
  public var horizon: LimitForecast.Horizon
  public var calendar: Calendar

  public init(limits: ClaudeLimits, day: LimitForecast.Day?, now: Date, horizon: LimitForecast.Horizon, calendar: Calendar) {
    self.limits = limits
    self.day = day
    self.now = now
    self.horizon = horizon
    self.calendar = calendar
  }

  public var isStale: Bool { now.timeIntervalSince(limits.capturedAt) > Self.staleAfter }

  public var freshness: String {
    if isStale { return "данные устарели" }
    let minutes = Int(max(now.timeIntervalSince(limits.capturedAt), 0) / 60)
    return minutes < 1 ? "обновлено только что" : "обновлено \(minutes) мин назад"
  }

  public func remaining(_ window: ClaudeWindow) -> Int { window.remaining(at: now) }

  /// «сброс в 00:10, через 3 ч 40 мин», с днём недели — «сброс пн в 11:00, через 14 ч». Истёкший — «сброс —»
  public func resetText(_ window: ClaudeWindow, weekday: Bool) -> String {
    guard window.resetsAt > now else { return "сброс ожидается, ждём обновления" }
    let day = weekday ? "\(weekdayName(window.resetsAt)) " : ""
    return
      "сброс \(day)в \(ActivityLayouts.clock(window.resetsAt, calendar: calendar)), через \(duration(window.resetsAt.timeIntervalSince(now)))"
  }

  /// Строка прогноза под карточками. nil — прогноза нет или данные устарели
  public var forecastText: String? {
    guard !isStale, let day else { return nil }
    if let runsOut = day.weekRunsOutAt, let week = limits.sevenDay {
      return
        "Неделя кончится в \(weekdayName(runsOut)) около \(ActivityLayouts.clock(runsOut, calendar: calendar)), сброс \(weekdayName(week.resetsAt))"
    }
    let spent = Int(day.spent.rounded())
    guard let projected = day.projected else { return "Наблюдаемый расход \(spent)% недели, прогноза пока нет" }
    let norm = Int(LimitForecast.dailyBudget.rounded())
    return "Наблюдаемый расход \(spent)% недели, \(horizonText) ≈ \(Int(projected.rounded()))%, ориентир \(norm)% в день"
  }

  private var horizonText: String {
    let end = LimitForecast.horizonDate(horizon, now: now, calendar: calendar)
    return end == LimitForecast.horizonDate(.midnight, now: now, calendar: calendar)
      ? "к полуночи"
      : "к \(ActivityLayouts.clock(end, calendar: calendar))"
  }

  private func weekdayName(_ date: Date) -> String {
    Self.weekdays[calendar.component(.weekday, from: date) - 1]
  }

  /// «3 ч 40 мин», «14 ч» (от 10 часов минуты не пишем), «40 мин»
  private func duration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds / 60)
    let hours = total / 60
    let minutes = total % 60
    if hours == 0 { return "\(minutes) мин" }
    if hours >= 10 || minutes == 0 { return "\(hours) ч" }
    return "\(hours) ч \(minutes) мин"
  }
}
