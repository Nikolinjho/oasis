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

    // кнопки плеера должны нажиматься, но окно не должно становиться главным
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// SwiftUI не должен добавлять safe area под вырез
final class ZeroSafeAreaHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
}
