import AppKit
import IslandCore

/// Фокус получает только явный клик по редактору. Поздний HUD не активирует чужое приложение.
@MainActor
final class ClaudeAgentInputController {
  private(set) var active = false
  private let store: IslandStore
  private weak var panel: NotchPanel?
  private weak var previousApp: NSRunningApplication?
  private var lease: PresentationLease?
  private var generation = UUID()
  private var suspended = false
  private var restoreFocus = false
  private var provider = AgentProvider.claude
  private var observer: NSObjectProtocol?

  init(store: IslandStore) {
    self.store = store
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      let bundle = application?.bundleIdentifier
      MainActor.assumeIsolated {
        guard let self, self.active, bundle != Bundle.main.bundleIdentifier,
          bundle == NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        else { return }
        self.restoreFocus = false
        if !self.suspended { self.end(restorePrevious: false) }
      }
    }
  }

  isolated deinit {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
  }

  func setActive(_ value: Bool, panel: NotchPanel?) {
    if value {
      guard let panel else { return }
      self.panel = panel
      begin()
    } else {
      end(restorePrevious: true)
    }
  }

  private func begin() {
    if !active { previousApp = NSWorkspace.shared.frontmostApplication }
    if let lease { store.releaseAttention(lease) }
    provider = store.activeAgentsPanel.provider
    lease = store.acquireAttention(owner: .agents(store.activeAgentsPanel.selectedRequestID))
    active = true
    store.agentInputActive = true
    generation = UUID()
    suspended = false
    panel?.acceptsAgentInput = true
    NSApp.activate(ignoringOtherApps: true)
    panel?.makeKeyAndOrderFront(nil)
  }

  private func end(restorePrevious: Bool) {
    guard active else { return }
    let shouldRestore = restorePrevious && panel?.isKeyWindow == true && isAppFrontmost
    active = false
    store.agentInputActive = false
    generation = UUID()
    suspended = false
    restoreFocus = false
    panel?.acceptsAgentInput = false
    panel?.makeFirstResponder(nil)
    panel?.resignKey()
    if let lease { store.releaseAttention(lease) }
    lease = nil
    if shouldRestore { previousApp?.activate() }
    previousApp = nil
  }

  func surfaceChanged(_ surface: Surface) {
    guard active else { return }
    if case .hud = surface {
      if !suspended { restoreFocus = panel?.isKeyWindow == true && isAppFrontmost }
      suspended = true
      panel?.resignKey()
      return
    }
    guard surface == .expanded, store.model.expandedView == provider.view else {
      end(restorePrevious: false)
      return
    }
    guard suspended else { return }
    suspended = false
    guard restoreFocus && isAppFrontmost else {
      end(restorePrevious: false)
      return
    }
    let current = generation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      guard let self, active, generation == current, isAppFrontmost,
        store.model.surface == .expanded, store.model.expandedView == provider.view,
        let panel, let content = panel.contentView, let editor = Self.editor(in: content)
      else { return }
      panel.makeKeyAndOrderFront(nil)
      panel.makeFirstResponder(editor)
    }
  }

  private var isAppFrontmost: Bool {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
  }

  private static func editor(in view: NSView) -> NSTextView? {
    if let input = view as? NSTextView, input.isEditable { return input }
    return view.subviews.lazy.compactMap { editor(in: $0) }.first
  }
}
