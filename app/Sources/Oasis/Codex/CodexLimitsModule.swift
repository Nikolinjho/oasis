import Combine
import Foundation
import IslandCore
import IslandSources

@MainActor
final class CodexLimitsModule: ObservableObject {
  @Published var enabled: Bool {
    didSet {
      guard enabled != oldValue else { return }
      defaults.set(enabled, forKey: "codex.limits.enabled")
      if enabled { start() } else { stop() }
    }
  }
  @Published private(set) var panel = CodexLimitsPanel()
  private let source: CodexLimitsSource
  private let store: IslandStore
  private let defaults: UserDefaults

  init(store: IslandStore, defaults: UserDefaults = .standard, source: CodexLimitsSource = CodexLimitsSource()) {
    self.store = store
    self.defaults = defaults
    self.source = source
    enabled = defaults.object(forKey: "codex.limits.enabled") as? Bool ?? true
  }

  func start() {
    guard enabled else { return }
    store.applyCodex(panel)
    source.start { [weak self] update in
      guard let self, self.enabled else { return }
      switch update {
      case .limits(let limits): panel = CodexLimitsPanel(limits: limits, status: nil)
      case .unavailable(let message):
        panel.status = message
        panel.now = Date()
      }
      store.applyCodex(panel)
    }
  }

  func stop() {
    source.stop()
    panel = CodexLimitsPanel()
    store.applyCodex(nil)
  }

  func refresh() { source.refresh() }
}
