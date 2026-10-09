import Foundation

/// Содержимое уведомления Claude Code.
public struct ClaudeNotice: Equatable, Sendable {
  public enum Reason: Equatable, Sendable {
    case threshold(Int)
    case runsOut
    case reset
  }

  public var reason: Reason
  public var remaining: Int
  public var resetsAt: Date?
  public var runsOutAt: Date?
  public var urgent: Bool
  public var sound: IslandSound?

  public init(reason: Reason, remaining: Int, resetsAt: Date?, runsOutAt: Date?, urgent: Bool, sound: IslandSound?) {
    self.reason = reason
    self.remaining = remaining
    self.resetsAt = resetsAt
    self.runsOutAt = runsOutAt
    self.urgent = urgent
    self.sound = sound
  }
}

public struct ClaudeAlertConfig: Equatable, Sendable {
  public var sessionWarning: Bool
  public var thresholds: Set<Int>
  public var criticalSound: Bool
  public var resetNotice: Bool

  public init(sessionWarning: Bool, thresholds: Set<Int>, criticalSound: Bool, resetNotice: Bool) {
    self.sessionWarning = sessionWarning
    self.thresholds = thresholds
    self.criticalSound = criticalSound
    self.resetNotice = resetNotice
  }

  public static let `default` = ClaudeAlertConfig(
    sessionWarning: true, thresholds: [50, 25, 10, 5], criticalSound: true, resetNotice: false)
}

/// Пороги и прогноз срабатывают по одному разу за окно. Первый снимок задаёт молчаливую исходную точку.
public struct ClaudeThresholdTracker: Equatable, Sendable {
  public private(set) var fired: Set<Int> = []
  public private(set) var window: Date?
  private var warnedRunsOut = false
  private var resetHandled = false
  private var lastRemaining: Int?
  private var previousConfig: ClaudeAlertConfig?
  private var latestCapture: Date?

  public init() {}

  public mutating func update(
    _ limits: ClaudeLimits, runsOutAt: Date?, now: Date, config: ClaudeAlertConfig
  ) -> ClaudeNotice? {
    guard let five = limits.fiveHour, limits.capturedAt <= now,
      latestCapture.map({ limits.capturedAt >= $0 }) ?? true
    else { return nil }
    // Опоздавший файл прошлого окна не должен заново взвести уже пройденные пороги.
    if let window, five.resetsAt < window, !ClaudeWindow.sameWindow(window, five.resetsAt) { return nil }
    latestCapture = limits.capturedAt
    let remaining = five.remaining(at: now)
    let baselineChanged =
      previousConfig.map {
        $0.thresholds != config.thresholds || $0.sessionWarning != config.sessionWarning
      } ?? false
    let resetEnabled = previousConfig.map { !$0.resetNotice && config.resetNotice } ?? false
    previousConfig = config
    let forecast = validForecast(runsOutAt, limits: limits, five: five, remaining: remaining, now: now)

    guard let window, ClaudeWindow.sameWindow(window, five.resetsAt) else {
      let isFirst = self.window == nil
      let wasPartial = (lastRemaining ?? 100) < 100 && !resetHandled
      startWindow(five.resetsAt, remaining: remaining, config: config, runsOutAt: forecast)
      resetHandled = now >= five.resetsAt
      return !isFirst && !resetEnabled && config.resetNotice && wasPartial && !resetHandled
        ? resetNotice(remaining: remaining) : nil
    }

    if now >= five.resetsAt {
      return expireWindow(notify: !resetEnabled && config.resetNotice)
    }

    lastRemaining = remaining
    let passed = Self.passed(remaining: remaining, config: config)
    let fresh = passed.subtracting(fired)
    fired.formUnion(passed)
    // Переключение настроек потребляет текущие пороги и прогноз без исторических уведомлений.
    guard config.sessionWarning, !baselineChanged else {
      warnedRunsOut = warnedRunsOut || forecast != nil
      return nil
    }
    if let lowest = fresh.min() {
      warnedRunsOut = warnedRunsOut || forecast != nil
      let urgent = lowest <= 5
      return ClaudeNotice(
        reason: .threshold(lowest), remaining: remaining, resetsAt: five.resetsAt, runsOutAt: forecast,
        urgent: urgent, sound: urgent && config.criticalSound ? .lowBattery : nil)
    }
    if let forecast, !warnedRunsOut {
      warnedRunsOut = true
      return ClaudeNotice(
        reason: .runsOut, remaining: remaining, resetsAt: five.resetsAt, runsOutAt: forecast, urgent: false, sound: nil)
    }
    return nil
  }

  /// Порог означает «ниже», кроме 0%: исчерпание срабатывает при ровно нулевом остатке.
  static func passed(remaining: Int, config: ClaudeAlertConfig) -> Set<Int> {
    config.thresholds.filter { (1...100).contains($0) }.union([0]).filter {
      $0 == 0 ? remaining == 0 : remaining < $0
    }
  }

  private mutating func startWindow(_ resetsAt: Date, remaining: Int, config: ClaudeAlertConfig, runsOutAt: Date?) {
    window = resetsAt
    fired = Self.passed(remaining: remaining, config: config)
    warnedRunsOut = runsOutAt != nil
    resetHandled = false
    lastRemaining = remaining
  }

  private mutating func expireWindow(notify: Bool) -> ClaudeNotice? {
    guard !resetHandled else { return nil }
    let wasPartial = (lastRemaining ?? 100) < 100
    resetHandled = true
    fired = []
    warnedRunsOut = false
    lastRemaining = 100
    return notify && wasPartial ? resetNotice(remaining: 100) : nil
  }

  private func validForecast(
    _ forecast: Date?, limits: ClaudeLimits, five: ClaudeWindow, remaining: Int, now: Date
  ) -> Date? {
    guard let forecast, forecast > now, forecast < five.resetsAt, remaining > 0,
      now.timeIntervalSince(limits.capturedAt) <= LimitForecast.maxSampleAge
    else { return nil }
    return forecast
  }

  private func resetNotice(remaining: Int) -> ClaudeNotice {
    ClaudeNotice(reason: .reset, remaining: remaining, resetsAt: nil, runsOutAt: nil, urgent: false, sound: .chime)
  }
}
