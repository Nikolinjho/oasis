import AppKit
import IslandCore
import IslandUI
import Observation
import SwiftUI

enum SoonComposerMode: Equatable {
  case new
  case existing(SoonReminder, action: SoonAction)
}

@MainActor
@Observable
final class SoonComposerController {
  var title = ""
  var duration = "15 мин"
  private(set) var submitting = false
  private(set) var error: String?
  private(set) var isOpen = false
  var authorizationPending = false
  private(set) var mode = SoonComposerMode.new
  @ObservationIgnored private var panel: SoonComposerPanel?
  @ObservationIgnored private weak var previousApp: NSRunningApplication?
  @ObservationIgnored private var monitors: [Any] = []
  @ObservationIgnored private var suspendedForHUD = false
  @ObservationIgnored private var restoreAfterHUD = true
  @ObservationIgnored private var submission: Task<Void, Never>?
  @ObservationIgnored var onEditing: (Bool) -> Void = { _ in }
  @ObservationIgnored var frame: () -> CGRect = {
    let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = IslandGeometry.windowSize
    return CGRect(x: screen.midX - size.width / 2, y: screen.maxY - size.height, width: size.width, height: size.height)
  }
  @ObservationIgnored var submit: (String, String, SoonComposerMode) async throws -> Void = { _, _, _ in }

  func show(_ mode: SoonComposerMode) {
    guard !submitting else { return }
    if self.mode != mode {
      self.mode = mode
      switch mode {
      case .new:
        title = ""
        duration = "15 мин"
      case .existing(let reminder, _):
        title = reminder.title
        duration = "\(reminder.durationSeconds) сек"
      }
      error = nil
    }
    if !isOpen { previousApp = NSWorkspace.shared.frontmostApplication }
    isOpen = true
    onEditing(true)
    let panel = self.panel ?? makePanel()
    self.panel = panel
    panel.setFrame(frame(), display: true)
    panel.makeKeyAndOrderFront(nil)
    panel.orderFrontRegardless()
    installMonitors()
  }

  func close(force: Bool = false) {
    guard isOpen, force || (!submitting && !authorizationPending) else { return }
    if force { submission?.cancel() }
    let shouldRestore =
      panel?.isKeyWindow == true && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
    panel?.orderOut(nil)
    monitors.forEach(NSEvent.removeMonitor)
    monitors.removeAll()
    panel = nil
    isOpen = false
    suspendedForHUD = false
    onEditing(false)
    if shouldRestore { previousApp?.activate() }
    previousApp = nil
  }

  func surfaceChanged(_ surface: Surface) {
    guard isOpen else { return }
    if case .hud = surface {
      if !suspendedForHUD { restoreAfterHUD = true }
      suspendedForHUD = true
      panel?.orderOut(nil)
    } else if suspendedForHUD {
      suspendedForHUD = false
      if restoreAfterHUD { panel?.makeKeyAndOrderFront(nil) }
      panel?.orderFrontRegardless()
    }
  }

  private func save() {
    guard !submitting else { return }
    submitting = true
    error = nil
    submission = Task { [weak self] in
      guard let self else { return }
      do {
        try await submit(title, duration, mode)
        guard !Task.isCancelled else {
          submitting = false
          return
        }
        submitting = false
        title = ""
        duration = "15 мин"
        mode = .new
        close()
      } catch {
        guard !Task.isCancelled else {
          submitting = false
          return
        }
        self.error = error.localizedDescription
        submitting = false
      }
      submission = nil
    }
  }

  private func makePanel() -> SoonComposerPanel {
    let panel = SoonComposerPanel(frame: frame())
    let host = ZeroSafeAreaHostingView(rootView: SoonComposerRoot(controller: self))
    host.sizingOptions = []
    host.frame = CGRect(origin: .zero, size: frame().size)
    host.autoresizingMask = [.width, .height]
    panel.contentView = host
    return panel
  }

  private func installMonitors() {
    guard monitors.isEmpty else { return }
    if let global = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown],
      handler: { [weak self] _ in
        MainActor.assumeIsolated { self?.outsideClick() }
      })
    {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown],
      handler: { [weak self] event in
        MainActor.assumeIsolated {
          guard let self else { return }
          if let panel = self.panel, event.window === panel {
            let size = IslandGeometry.expanded
            let body = CGRect(
              x: (panel.frame.width - size.width) / 2, y: panel.frame.height - size.height,
              width: size.width, height: size.height)
            if body.contains(event.locationInWindow) { return }
          }
          self.outsideClick()
        }
        return event
      })
    {
      monitors.append(local)
    }
  }

  private func outsideClick() {
    if suspendedForHUD { restoreAfterHUD = false }
    guard !authorizationPending, !submitting else { return }
    close()
  }

  private struct SoonComposerRoot: View {
    @Bindable var controller: SoonComposerController
    private let spec = IslandShapeSpec(size: CGSize(width: 345, height: 175), bottomRadius: 35, shoulder: 18.3)
    var body: some View {
      ZStack(alignment: .top) {
        IslandShape(spec: spec).fill(.black)
        SoonComposerView(
          title: $controller.title, duration: $controller.duration,
          heading: controller.mode == .new ? "Новое напоминание" : "Изменить напоминание",
          error: controller.error, submitting: controller.submitting,
          onSubmit: { controller.save() }, onClose: { controller.close() })
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }
}

private final class SoonComposerPanel: NSPanel {
  init(frame: CGRect) {
    super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isMovable = false
  }
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
      let action: Selector?
      switch event.charactersIgnoringModifiers?.lowercased() {
      case "a": action = #selector(NSText.selectAll(_:))
      case "c": action = #selector(NSText.copy(_:))
      case "v": action = #selector(NSText.paste(_:))
      case "x": action = #selector(NSText.cut(_:))
      default: action = nil
      }
      if let action { return NSApp.sendAction(action, to: nil, from: self) }
    }
    return super.performKeyEquivalent(with: event)
  }
}
