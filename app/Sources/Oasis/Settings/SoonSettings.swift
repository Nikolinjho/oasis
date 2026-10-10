import Combine
import Foundation

@MainActor
final class SoonSettings: ObservableObject {
  var onChange: () -> Void = {}
  private let defaults: UserDefaults
  @Published var enabled: Bool { didSet { save(oldValue, enabled, "enabled") } }
  @Published var showInIsland: Bool { didSet { save(oldValue, showInIsland, "showInIsland") } }
  @Published var systemNotifications: Bool { didSet { save(oldValue, systemNotifications, "systemNotifications") } }
  @Published var playSound: Bool { didSet { save(oldValue, playSound, "playSound") } }
  @Published var hidePeekInFullscreen: Bool { didSet { save(oldValue, hidePeekInFullscreen, "hidePeekInFullscreen") } }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    enabled = defaults.object(forKey: "soon.enabled") as? Bool ?? true
    showInIsland = defaults.object(forKey: "soon.showInIsland") as? Bool ?? true
    systemNotifications = defaults.object(forKey: "soon.systemNotifications") as? Bool ?? true
    playSound = defaults.object(forKey: "soon.playSound") as? Bool ?? true
    hidePeekInFullscreen = defaults.object(forKey: "soon.hidePeekInFullscreen") as? Bool ?? true
  }

  private func save(_ old: Bool, _ new: Bool, _ key: String) {
    guard old != new else { return }
    defaults.set(new, forKey: "soon." + key)
    onChange()
  }
}
