import AppKit
import SwiftUI

/// ⌘W закрывает окно: приложение — accessory без app-меню, «File → Close» биндить неоткуда,
/// поэтому cmd+w перехватываем сами
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.charactersIgnoringModifiers == "w", event.modifierFlags.contains(.command) {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Окно настроек 620×687: не ресайзится, активна только кнопка закрытия, заголовок — название страницы
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // приложение без Dock-иконки: без активации окно откроется под активным приложением
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 659),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = SettingsPage.general.title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
        window.center()
        return window
    }
}
