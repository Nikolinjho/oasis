import Foundation
import Testing

@testable import IslandCore

struct ValueThrottleTests {
  let start = Date(timeIntervalSinceReferenceDate: 0)

  @Test("Первое значение уходит сразу, дальше — не чаще интервала")
  func throttles() {
    var throttle = ValueThrottle<Double>(interval: 1.0 / 30)
    #expect(throttle.offer(0.1, at: start) == 0.1)
    #expect(throttle.offer(0.2, at: start.addingTimeInterval(0.01)) == nil)
    #expect(throttle.offer(0.3, at: start.addingTimeInterval(0.02)) == nil)
    #expect(throttle.offer(0.4, at: start.addingTimeInterval(0.04)) == 0.4)
  }

  @Test("Конец жеста отдаёт последнее значение, даже если его придержал интервал")
  func finishDeliversHeld() {
    var throttle = ValueThrottle<Double>(interval: 1.0 / 30)
    _ = throttle.offer(0.1, at: start)
    _ = throttle.offer(0.5, at: start.addingTimeInterval(0.01))
    #expect(throttle.finish(0.5) == 0.5)
  }

  @Test("Конец жеста не дублирует уже отправленное значение")
  func finishSkipsSent() {
    var throttle = ValueThrottle<Double>(interval: 1.0 / 30)
    _ = throttle.offer(0.1, at: start)
    #expect(throttle.finish(0.1) == nil)
  }

  @Test("После конца жеста следующий начинается без задержки")
  func finishResets() {
    var throttle = ValueThrottle<Double>(interval: 1.0 / 30)
    _ = throttle.offer(0.1, at: start)
    _ = throttle.finish(0.1)
    #expect(throttle.offer(0.1, at: start.addingTimeInterval(0.01)) == 0.1)
  }
}
