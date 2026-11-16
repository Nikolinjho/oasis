import Foundation
import IslandCore
import Testing

struct CodexLimitsMonitorTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  var config: ClaudeAlertConfig { .default }

  func limits(_ used: Int, at date: Date, reset: Date? = nil, weekUsed: Int = 20, bucket: String = "codex", weekReset: Date? = nil)
    -> CodexLimits
  {
    let resetValue = reset ?? now.addingTimeInterval(7200)
    let data = Data(
      """
      {"rateLimitsByLimitId": {"\(bucket)": {
        "primary": {"usedPercent": \(used), "windowDurationMins": 300, "resetsAt": \(resetValue.timeIntervalSince1970)},
        "secondary": {"usedPercent": \(weekUsed), "windowDurationMins": 10080, "resetsAt": \((weekReset ?? now.addingTimeInterval(604800)).timeIntervalSince1970)}
      }}}
      """.utf8)
    return CodexLimits.parse(data, now: date)!
  }

  @Test("Первый снимок тихий, пересечение нескольких порогов даёт одно предупреждение, повтор не звучит")
  func thresholds() {
    var monitor = CodexLimitsMonitor()
    #expect(monitor.receive(limits(40, at: now), now: now, config: config) == nil)
    let next = now.addingTimeInterval(60)
    let notice = monitor.receive(limits(96, at: next), now: next, config: config)
    #expect(notice?.details.reason == .threshold(5))
    #expect(notice?.details.remaining == 4)
    #expect(notice?.details.sound == .lowBattery)
    #expect(monitor.receive(limits(96, at: next), now: next, config: config) == nil)
    let zero = monitor.receive(limits(100, at: next.addingTimeInterval(60)), now: next.addingTimeInterval(60), config: config)
    #expect(zero?.details.reason == .threshold(0))
  }

  @Test("Сброс подтверждается свежим снимком следующего окна, старое окно после срока молчит")
  func confirmedReset() {
    var monitor = CodexLimitsMonitor()
    var config = config
    config.resetNotice = true
    let reset = now.addingTimeInterval(60)
    _ = monitor.receive(limits(80, at: now, reset: reset), now: now, config: config)
    let later = now.addingTimeInterval(120)
    #expect(monitor.receive(limits(80, at: later, reset: reset), now: later, config: config) == nil)
    let notice = monitor.receive(limits(0, at: later, reset: later.addingTimeInterval(18000)), now: later, config: config)
    #expect(notice?.details.reason == .reset)
    #expect(notice?.details.remaining == 100)
    #expect(monitor.receive(limits(0, at: later, reset: later.addingTimeInterval(18000)), now: later, config: config) == nil)
  }

  @Test("Опоздавшие и устаревшие снимки не создают предупреждения и не подменяют свежий остаток")
  func staleAndOutOfOrder() {
    var monitor = CodexLimitsMonitor()
    _ = monitor.receive(limits(30, at: now), now: now, config: config)
    #expect(monitor.receive(limits(100, at: now.addingTimeInterval(-60)), now: now, config: config) == nil)
    #expect(monitor.panel(now: now).limits?.buckets.first?.windows.first?.remaining == 70)
    let later = now.addingTimeInterval(1900)
    #expect(monitor.receive(limits(100, at: now.addingTimeInterval(10)), now: later, config: config) == nil)
    #expect(monitor.panel(now: later).forecastText == nil)
  }

  @Test("Изменение порогов не воспроизводит старые предупреждения, звук можно выключить")
  func settingsBaseline() {
    var monitor = CodexLimitsMonitor()
    var config = config
    _ = monitor.receive(limits(40, at: now), now: now, config: config)
    config.thresholds = [5]
    config.criticalSound = false
    let next = now.addingTimeInterval(60)
    #expect(monitor.receive(limits(96, at: next), now: next, config: config) == nil)
    let zero = monitor.receive(limits(100, at: next.addingTimeInterval(60)), now: next.addingTimeInterval(60), config: config)
    #expect(zero?.details.reason == .threshold(0))
    #expect(zero?.details.sound == nil)
  }

  @Test("Дополнительный bucket не подменяет основное окно Codex")
  func bucketIsolation() {
    var monitor = CodexLimitsMonitor()
    _ = monitor.receive(limits(40, at: now), now: now, config: config)
    #expect(
      monitor.receive(limits(100, at: now.addingTimeInterval(60), bucket: "other"), now: now.addingTimeInterval(60), config: config) == nil)
  }

  @Test("Прогноз дня использует историю недели и выбранный конец рабочего дня")
  func forecast() {
    var monitor = CodexLimitsMonitor()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 10800)!
    let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))!
    _ = monitor.receive(limits(20, at: start, weekUsed: 20, weekReset: start.addingTimeInterval(7200)), now: start, config: config)
    let end = start.addingTimeInterval(1200)
    _ = monitor.receive(limits(30, at: end, weekUsed: 22, weekReset: start.addingTimeInterval(7200)), now: end, config: config)
    let midnight = monitor.panel(now: end, horizon: .midnight, calendar: calendar)
    let workday = monitor.panel(now: end, horizon: .workdayEnd(minutes: 1080), calendar: calendar)
    #expect(midnight.forecastText?.contains("к полуночи") == true)
    #expect(workday.forecastText?.contains("к 18:00") == true)
    #expect(midnight.forecastText != workday.forecastText)
  }
}
