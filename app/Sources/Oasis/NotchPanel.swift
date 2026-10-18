import AppKit
import SwiftUI

/// Прозрачное окно над вырезом. Размер фиксированный, анимируется только форма внутри,
/// поэтому пружина не дёргается от ресайза окна
final class NotchPanel: NSPanel {
  init(frame: CGRect) {
    super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    animationBehavior = .none
    isMovable = false
    ignoresMouseEvents = true
    acceptsMouseMovedEvents = true
  }

  // окно не забирает фокус у активного приложения: кнопки в NSHostingView срабатывают и с первого клика
  var acceptsAgentInput = false
  override var canBecomeKey: Bool { acceptsAgentInput }
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if acceptsAgentInput, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
      let action: Selector?
      // Правки работают и в русской раскладке, где charactersIgnoringModifiers не содержит a/c/v/x.
      switch event.keyCode {
      case 0: action = #selector(NSText.selectAll(_:))
      case 8: action = #selector(NSText.copy(_:))
      case 9: action = #selector(NSText.paste(_:))
      case 7: action = #selector(NSText.cut(_:))
      default: action = nil
      }
      if let action { return NSApp.sendAction(action, to: nil, from: self) }
    }
    return super.performKeyEquivalent(with: event)
  }

  override var canBecomeMain: Bool { false }
}

/// SwiftUI не должен добавлять safe area под вырез
final class ZeroSafeAreaHostingView<Content: View>: NSHostingView<Content> {
  override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
}
