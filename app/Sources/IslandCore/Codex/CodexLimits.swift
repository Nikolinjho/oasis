import CoreFoundation
import Foundation

/// Снимок лимитов аккаунта Codex. Длительности окон задаёт сервер.
public struct CodexLimits: Equatable, Sendable {
  public struct Window: Equatable, Sendable, Identifiable {
    public let id: String
    public let usedPercent: Double
    public let durationMinutes: Int?
    public let resetsAt: Date?

    public var remaining: Int { Int((100 - usedPercent).rounded(.down)) }

    public var title: String {
      guard let minutes = durationMinutes else { return id == "primary" ? "Основной лимит" : "Дополнительный лимит" }
      if minutes % 1440 == 0 { return Self.quantity(minutes / 1440, forms: ["день", "дня", "дней"]) }
      if minutes % 60 == 0 { return Self.quantity(minutes / 60, forms: ["час", "часа", "часов"]) }
      return "\(minutes) мин"
    }

    private static func quantity(_ value: Int, forms: [String]) -> String {
      let index = (11...14).contains(value % 100) ? 2 : value % 10 == 1 ? 0 : (2...4).contains(value % 10) ? 1 : 2
      return "\(value) \(forms[index])"
    }
  }

  public struct Bucket: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let windows: [Window]
  }

  public let buckets: [Bucket]
  public let capturedAt: Date

  public static func parse(_ data: Data, now: Date = Date()) -> CodexLimits? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    var buckets: [Bucket] = []
    if let values = object["rateLimitsByLimitId"] as? [String: Any] {
      for key in values.keys.sorted() {
        if let value = values[key] as? [String: Any], let bucket = bucket(value, id: key) { buckets.append(bucket) }
      }
      buckets.sort { $0.id == "codex" && $1.id != "codex" }
    }
    if buckets.isEmpty, let value = object["rateLimits"] as? [String: Any],
      let bucket = bucket(value, id: value["limitId"] as? String ?? "codex")
    {
      buckets = [bucket]
    }
    return buckets.isEmpty ? nil : CodexLimits(buckets: buckets, capturedAt: now)
  }

  private static func bucket(_ value: [String: Any], id: String) -> Bucket? {
    let windows = ["primary", "secondary"].compactMap { key -> Window? in
      guard let raw = value[key] as? [String: Any], let used = number(raw["usedPercent"]) else { return nil }
      let duration = number(raw["windowDurationMins"]).flatMap { $0 >= 1 && $0 <= 525600 ? Int($0) : nil }
      let reset = number(raw["resetsAt"]).flatMap {
        $0 > 0 && $0 <= Date.distantFuture.timeIntervalSince1970 ? Date(timeIntervalSince1970: $0) : nil
      }
      return Window(id: key, usedPercent: min(100, max(0, used)), durationMinutes: duration, resetsAt: reset)
    }
    guard !windows.isEmpty else { return nil }
    let name = (value["limitName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    return Bucket(id: id, title: name ?? (id == "codex" ? "Codex" : id), windows: windows)
  }

  private static func number(_ value: Any?) -> Double? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
    return value.doubleValue
  }
}

public struct CodexLimitsPanel: Equatable, Sendable {
  public var limits: CodexLimits?
  public var status: String?
  public var now: Date
  public var forecastText: String?

  public init(limits: CodexLimits? = nil, status: String? = "Подключение…", now: Date = Date()) {
    self.limits = limits
    self.status = status
    self.now = now
  }

  public var freshness: String {
    guard let limits else { return "нет данных" }
    let minutes = Int(max(0, now.timeIntervalSince(limits.capturedAt)) / 60)
    if minutes >= 30 { return "данные устарели" }
    return minutes == 0 ? "обновлено только что" : "обновлено \(minutes) мин назад"
  }
}
