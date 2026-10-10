import AppKit
import IslandSources

@MainActor
final class SoonModuleLifecycle {
  private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
  private var generation = 0

  func start(_ module: SoonModule) {
    guard tokens.isEmpty else { return }
    generation += 1
    let activeGeneration = generation
    for (center, name) in [
      (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
      (NotificationCenter.default, NSApplication.didBecomeActiveNotification),
      (NotificationCenter.default, Notification.Name.NSSystemClockDidChange),
      (NotificationCenter.default, Notification.Name.NSSystemTimeZoneDidChange),
      (DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsUnlocked")),
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
    tokens.removeAll()
  }
}
