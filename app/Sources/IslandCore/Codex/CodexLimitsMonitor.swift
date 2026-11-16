import Foundation

/// Пороги Codex используют подтверждённые окна. Время сброса само по себе не восстанавливает остаток.
public struct CodexLimitsMonitor: Sendable {
  private var latest: CodexLimits?
  private var history: [ClaudeLimits] = []
  private var tracker = ClaudeThresholdTracker()

  public init() {}

  public mutating func receive(_ limits: CodexLimits, now: Date, config: ClaudeAlertConfig) -> CodexNotice? {
    guard limits.capturedAt <= now, latest.map({ limits.capturedAt >= $0.capturedAt }) ?? true else { return nil }
    let sample = Self.forecastSample(limits)
    // Старое окно, пришедшее позднее по сети, не заменяет новое окно в панели и истории.
    if let previous = latest.map(Self.forecastSample)?.fiveHour, let current = sample.fiveHour,
      current.resetsAt < previous.resetsAt, !ClaudeWindow.sameWindow(current.resetsAt, previous.resetsAt)
    {
      return nil
    }
    latest = limits
    history.removeAll { $0.capturedAt < now.addingTimeInterval(-48 * 3600) || $0.capturedAt == limits.capturedAt }
    history.append(sample)
    if history.count > 3000 { history.removeFirst(history.count - 3000) }
    guard now.timeIntervalSince(limits.capturedAt) <= ClaudePanel.staleAfter,
      let primary = Self.primary(limits), let reset = primary.resetsAt, reset > now
    else { return nil }
    let forecast = LimitForecast.sessionRunsOutAt(history: history, now: now)
    guard let notice = tracker.update(sample, runsOutAt: forecast, now: now, config: config) else { return nil }
    return CodexNotice(details: notice, windowTitle: primary.title)
  }

  public func panel(
    now: Date, status: String? = nil, horizon: LimitForecast.Horizon = .midnight, calendar: Calendar = .current
  ) -> CodexLimitsPanel {
    var panel = CodexLimitsPanel(limits: latest, status: status, now: now)
    guard let latest, now.timeIntervalSince(latest.capturedAt) <= ClaudePanel.staleAfter else { return panel }
    let sample = Self.forecastSample(latest)
    if sample.sevenDay != nil {
      let day = LimitForecast.day(history: history, now: now, horizon: horizon, calendar: calendar)
      panel.forecastText =
        ClaudePanel(limits: sample, day: day, now: now, horizon: horizon, calendar: calendar).forecastText
        ?? "Прогноза пока нет: накапливаем историю расхода"
    } else {
      panel.forecastText = "Прогноза пока нет: недельное окно недоступно"
    }
    return panel
  }

  private static func primary(_ limits: CodexLimits) -> CodexLimits.Window? {
    limits.buckets.first { $0.id == "codex" }?.windows.first { $0.id == "primary" }
  }

  /// Общая математика прогноза принимает окна Claude. Недельный прогноз применим только к окну 7 дней.
  private static func forecastSample(_ limits: CodexLimits) -> ClaudeLimits {
    let bucket = limits.buckets.first { $0.id == "codex" }
    func window(_ value: CodexLimits.Window?) -> ClaudeWindow? {
      guard let value, let reset = value.resetsAt else { return nil }
      return ClaudeWindow(usedPercent: 100 - value.remaining, resetsAt: reset)
    }
    return ClaudeLimits(
      fiveHour: window(primary(limits)),
      sevenDay: window(bucket?.windows.first { $0.id == "secondary" && $0.durationMinutes == 10080 }),
      capturedAt: limits.capturedAt)
  }
}
