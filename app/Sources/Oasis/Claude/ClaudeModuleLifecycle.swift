import AppKit

/// Наблюдатели живут только вместе с модулем. Старые колбэки после stop игнорируются.
@MainActor
final class ClaudeModuleLifecycle {
  private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
  private var generation = 0

  func start(_ module: ClaudeModule) {
    guard tokens.isEmpty else { return }
    generation += 1
    let activeGeneration = generation
    for (center, name) in [
      (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
      (NotificationCenter.default, Notification.Name.NSSystemClockDidChange),
    ] {
      let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self, weak module] _ in
        Task { @MainActor [weak self, weak module] in
          guard let self, self.generation == activeGeneration, let module, module.isRunning else { return }
          module.systemTimeChanged()
        }
      }
      tokens.append((center, token))
    }
  }

  func stop() {
    generation += 1
    for (center, token) in tokens { center.removeObserver(token) }
    tokens = []
  }
}
