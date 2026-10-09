import Combine
import Foundation
import IslandCore

@MainActor
final class ClaudeSettings: ObservableObject {
  var onChange: () -> Void = {}
  private let defaults: UserDefaults
  @Published var enabled: Bool { didSet { save(oldValue, enabled, "enabled") } }
  @Published var sessionWarning: Bool { didSet { save(oldValue, sessionWarning, "sessionWarning") } }
  @Published var thresholds: [Int] { didSet { save(oldValue, thresholds, "thresholds") } }
  @Published var criticalSound: Bool { didSet { save(oldValue, criticalSound, "criticalSound") } }
  @Published var resetNotice: Bool { didSet { save(oldValue, resetNotice, "resetNotice") } }
  @Published var expandedView: Bool { didSet { save(oldValue, expandedView, "expandedView") } }
  @Published var forecastUntilWorkday: Bool { didSet { save(oldValue, forecastUntilWorkday, "forecastUntilWorkday") } }
  @Published var workdayEnd: Int { didSet { save(oldValue, workdayEnd, "workdayEnd") } }
  @Published var statuslineText: Bool { didSet { save(oldValue, statuslineText, "statuslineText") } }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    enabled = defaults.object(forKey: "claude.enabled") as? Bool ?? true
    sessionWarning = defaults.object(forKey: "claude.sessionWarning") as? Bool ?? true
    thresholds = defaults.array(forKey: "claude.thresholds") as? [Int] ?? [50, 25, 10, 5]
    criticalSound = defaults.object(forKey: "claude.criticalSound") as? Bool ?? true
    resetNotice = defaults.bool(forKey: "claude.resetNotice")
    expandedView = defaults.object(forKey: "claude.expandedView") as? Bool ?? true
    forecastUntilWorkday = defaults.bool(forKey: "claude.forecastUntilWorkday")
    workdayEnd = defaults.object(forKey: "claude.workdayEnd") as? Int ?? 1200
    statuslineText = defaults.object(forKey: "claude.statuslineText") as? Bool ?? true
  }

  var alertConfig: ClaudeAlertConfig {
    ClaudeAlertConfig(
      sessionWarning: sessionWarning, thresholds: Set(thresholds).intersection([50, 25, 10, 5]),
      criticalSound: criticalSound, resetNotice: resetNotice)
  }

  var horizon: LimitForecast.Horizon {
    forecastUntilWorkday ? .workdayEnd(minutes: min(max(workdayEnd, 960), 1380)) : .midnight
  }

  private func save<T: Equatable>(_ old: T, _ new: T, _ key: String) {
    guard old != new else { return }
    defaults.set(new, forKey: "claude." + key)
    onChange()
  }
}
