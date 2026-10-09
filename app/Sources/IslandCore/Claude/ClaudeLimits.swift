import CoreFoundation
import Foundation

/// Одно окно подписки: наблюдаемый расход и время сброса.
public struct ClaudeWindow: Equatable, Sendable {
  public var usedPercent: Int
  public var resetsAt: Date

  public init(usedPercent: Int, resetsAt: Date) {
    self.usedPercent = min(max(usedPercent, 0), 100)
    self.resetsAt = resetsAt
  }

  /// После сброса это расчётный остаток, а не новое наблюдение Claude Code.
  public func remaining(at now: Date) -> Int {
    now >= resetsAt ? 100 : 100 - min(max(usedPercent, 0), 100)
  }

  public static func sameWindow(_ a: Date, _ b: Date) -> Bool {
    abs(a.timeIntervalSince(b)) < 60
  }
}

/// Снимок statusline Claude Code. Отсутствующее окно не означает нулевой расход.
public struct ClaudeLimits: Equatable, Sendable {
  public var fiveHour: ClaudeWindow?
  public var sevenDay: ClaudeWindow?
  public var capturedAt: Date

  public init(fiveHour: ClaudeWindow?, sevenDay: ClaudeWindow?, capturedAt: Date) {
    self.fiveHour = fiveHour
    self.sevenDay = sevenDay
    self.capturedAt = capturedAt
  }

  public var isEmpty: Bool { fiveHour == nil && sevenDay == nil }

  public static func parse(_ data: Data) -> ClaudeLimits? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let captured = timestamp(root["captured_at"])
    else { return nil }
    let limits = root["rate_limits"] as? [String: Any] ?? [:]
    return ClaudeLimits(
      fiveHour: window(limits["five_hour"]), sevenDay: window(limits["seven_day"]),
      capturedAt: Date(timeIntervalSince1970: captured))
  }

  /// Формат совпадает с файлом statusline: одна строка, ключи по алфавиту.
  public func jsonData() -> Data {
    var limits: [String: Any] = [:]
    if let fiveHour { limits["five_hour"] = Self.dictionary(fiveHour) }
    if let sevenDay { limits["seven_day"] = Self.dictionary(sevenDay) }
    let root: [String: Any] = ["captured_at": capturedAt.timeIntervalSince1970, "rate_limits": limits]
    return (try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])) ?? Data()
  }

  private static func number(_ value: Any?) -> Double? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
      value.doubleValue.isFinite
    else { return nil }
    return value.doubleValue
  }

  private static func timestamp(_ value: Any?) -> Double? {
    guard let value = number(value), value > 0, value <= Date.distantFuture.timeIntervalSince1970 else { return nil }
    return value
  }

  private static func window(_ value: Any?) -> ClaudeWindow? {
    guard let dict = value as? [String: Any], let used = number(dict["used_percentage"]),
      let resets = timestamp(dict["resets_at"])
    else { return nil }
    return ClaudeWindow(
      usedPercent: Int(min(max(used, 0), 100).rounded()), resetsAt: Date(timeIntervalSince1970: resets))
  }

  private static func dictionary(_ window: ClaudeWindow) -> [String: Any] {
    ["used_percentage": min(max(window.usedPercent, 0), 100), "resets_at": window.resetsAt.timeIntervalSince1970]
  }
}
