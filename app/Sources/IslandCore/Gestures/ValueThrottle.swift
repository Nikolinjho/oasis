import Foundation

/// Пропускает значения жеста не чаще interval; конец жеста (finish) отдаёт последнее всегда,
/// если оно ещё не ушло. Строка громкости: CoreAudio не нужно дёргать на каждый кадр перетаскивания
public struct ValueThrottle<Value: Equatable>: Equatable {
  public let interval: TimeInterval
  private var lastSentAt: Date?
  private var lastSent: Value?

  public init(interval: TimeInterval) {
    self.interval = interval
  }

  /// Значение для отправки или nil — интервал с прошлой отправки ещё не прошёл
  public mutating func offer(_ value: Value, at now: Date) -> Value? {
    if let lastSentAt, now.timeIntervalSince(lastSentAt) < interval { return nil }
    lastSentAt = now
    lastSent = value
    return value
  }

  /// Конец жеста: последнее значение, если оно не совпадает с отправленным. Следующий жест — без задержки
  public mutating func finish(_ value: Value) -> Value? {
    defer {
      lastSentAt = nil
      lastSent = nil
    }
    return value == lastSent ? nil : value
  }
}
