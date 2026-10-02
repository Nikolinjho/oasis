import AppKit
import IslandSources

/// Следит, открыто ли полноэкранное приложение на экране с вырезом, и сообщает только об изменениях.
/// Пересчёт по смене Space, активации приложения и смене экранов, с задержкой 150 мс:
/// анимация перехода между Space ещё идёт, и окна полноэкранного приложения появляются не сразу
@MainActor
final class FullscreenMonitor {
  private let onChange: (Bool) -> Void
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []
  private var pending: Task<Void, Never>?
  private var last: Bool?

  init(onChange: @escaping (Bool) -> Void) {
    self.onChange = onChange
  }

  func start() {
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
      observe(workspace, name)
    }
    observe(.default, NSApplication.didChangeScreenParametersNotification)
    evaluate()
  }

  private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
    let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.scheduleEvaluation() }
    }
    observers.append((center, token))
  }

  private func scheduleEvaluation() {
    pending?.cancel()
    pending = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled else { return }
      self?.evaluate()
    }
  }

  private func evaluate() {
    let value = Self.isFullscreenNow()
    guard value != last else { return }
    last = value
    onChange(value)
  }

  private static func isFullscreenNow() -> Bool {
    let screens = NSScreen.screens
    guard let primary = screens.first,
      let notchScreen = screens.first(where: { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil })
    else { return false }
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    return FullscreenWindows.isFullscreen(
      windows: windows,
      frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
      ownPID: ProcessInfo.processInfo.processIdentifier,
      screen: FullscreenWindows.cgRect(ofScreenFrame: notchScreen.frame, primaryScreenHeight: primary.frame.height))
  }
}
