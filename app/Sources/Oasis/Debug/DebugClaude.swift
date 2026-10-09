import Foundation
import IslandCore

@MainActor
enum DebugClaude {
  /// Claude: снимки как от живого источника, история дня для прогноза, peek напрямую
  static func section(_ store: IslandStore, _ claude: ClaudeModule) -> DebugSection {
    func snapshot(five: Int? = nil, week: Int? = nil, fiveReset: TimeInterval = 3 * 3600 + 40 * 60) -> ClaudeLimits {
      let now = Date()
      let previous = claude.current
      return ClaudeLimits(
        fiveHour: ClaudeWindow(
          usedPercent: 100 - (five ?? previous?.fiveHour?.remaining(at: now) ?? 91),
          resetsAt: five == 100 ? now.addingTimeInterval(5 * 3600) : previous?.fiveHour?.resetsAt ?? now.addingTimeInterval(fiveReset)),
        sevenDay: ClaudeWindow(
          usedPercent: 100 - (week ?? previous?.sevenDay?.remaining(at: now) ?? 46),
          resetsAt: previous?.sevenDay?.resetsAt ?? now.addingTimeInterval(14 * 3600)),
        capturedAt: now)
    }
    var entries: [DebugEntry] = [91, 45, 20, 8, 3, 0].map { (remaining: Int) in
      .action(DebugAction(id: "claude.5h-\(remaining)", title: "5h \(remaining)% left") { claude.inject(snapshot(five: remaining)) })
    }
    entries.append(.separator)
    entries += [80, 46, 10].map { (remaining: Int) in
      .action(DebugAction(id: "claude.7d-\(remaining)", title: "7d \(remaining)% left") { claude.inject(snapshot(week: remaining)) })
    }
    entries += [
      .separator,
      .action(DebugAction(id: "claude.reset", title: "5h Window Reset") { claude.inject(snapshot(five: 100, fiveReset: 5 * 3600)) }),
      .action(
        DebugAction(id: "claude.day", title: "Last Four Hours") {
          claude.inject(history: workdayHistory())
        }),
      .action(DebugAction(id: "claude.none", title: "No Data") { claude.clear() }),
      .action(DebugAction(id: "claude.live", title: "Resume Live Data") { claude.resumeLive() }),
      .separator,
      .action(
        DebugAction(id: "claude.peek.low", title: "Peek 3% (urgent)") {
          store.send(
            .alertArrived(
              .claude(
                ClaudeNotice(
                  reason: .threshold(5), remaining: 3, resetsAt: Date().addingTimeInterval(40 * 60), runsOutAt: nil,
                  urgent: true, sound: .lowBattery))))
        }),
      .action(
        DebugAction(id: "claude.peek.runs-out", title: "Peek Runs Out Before Reset") {
          store.send(
            .alertArrived(
              .claude(
                ClaudeNotice(
                  reason: .runsOut, remaining: 38, resetsAt: Date().addingTimeInterval(3 * 3600),
                  runsOutAt: Date().addingTimeInterval(50 * 60), urgent: false, sound: nil))))
        }),
    ]
    return DebugSection(title: "Claude", entries: entries)
  }

  /// Наблюдаемый расход последних четырёх часов с общим временем сброса для каждой серии.
  private static func workdayHistory() -> [ClaudeLimits] {
    let now = Date()
    let start = now.addingTimeInterval(-4 * 3600)
    let weekReset = now.addingTimeInterval(3 * 86_400)
    let steps = max(Int(now.timeIntervalSince(start) / 1800), 1)
    let history = (0...steps).map { step in
      ClaudeLimits(
        fiveHour: ClaudeWindow(usedPercent: min(step * 4 % 100, 99), resetsAt: now.addingTimeInterval(2 * 3600)),
        sevenDay: ClaudeWindow(usedPercent: 40 + step, resetsAt: weekReset),
        capturedAt: start.addingTimeInterval(TimeInterval(step) * 1800))
    }

    return history
  }
}
