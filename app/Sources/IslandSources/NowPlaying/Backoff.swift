/// Задержки перезапуска адаптера: 1, 2, 4 … 30 с
public struct Backoff: Sendable {
  private var attempt = 0

  public init() {}

  public mutating func next() -> Duration {
    let seconds = min(30, 1 << min(attempt, 5))
    attempt += 1
    return .seconds(seconds)
  }

  public mutating func reset() {
    attempt = 0
  }
}
