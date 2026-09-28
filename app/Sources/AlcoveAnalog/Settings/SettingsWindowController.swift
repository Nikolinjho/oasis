import AppKit
import IslandCore
import SwiftUI

/// Чистая проверка «это ⌘W», без окна и responder chain — можно проверить юнит-тестом на синтетическом NSEvent.
/// deviceIndependentFlagsMask отсекает мусорные биты (numeric pad, function) вместо простого .contains(.command):
/// иначе Shift-⌘W тоже прошёл бы как закрытие
enum SettingsShortcut {
    static func isClose(_ event: NSEvent) -> Bool {
        event.type == .keyDown
            && event.charactersIgnoringModifiers?.lowercased() == "w"
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
    }
}

/// mainMenu есть (MainMenu.build(), пункт Close Window с ⌘W), но окно настроек не полагается
/// на путь через него: override — первый (дешёвый) слой перехвата, локальный монитор в контроллере —
/// второй, независимый от того, дошло ли дело до performKeyEquivalent вообще
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if SettingsShortcut.isClose(event) {
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
    private let playSound: (IslandSound) -> Void
    private var window: NSWindow?
    private var closeShortcutMonitor: Any?

    init(settings: AppSettings, playSound: @escaping (IslandSound) -> Void = { _ in }) {
        self.settings = settings
        self.playSound = playSound
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
        window.contentView = NSHostingView(rootView: SettingsView(
            settings: settings, playSound: playSound,
            onPageChange: { [weak window] page in window?.title = page.title }))
        window.center()
        installCloseShortcut(on: window)
        return window
    }

    /// Локальный монитор видит keyDown до того, как NSApplication решает, что это «key equivalent»:
    /// не зависит от mainMenu и от того, срабатывает ли performKeyEquivalent окна
    private func installCloseShortcut(on window: NSWindow) {
        closeShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
            guard let window, event.window === window, SettingsShortcut.isClose(event) else { return event }
            window.close()
            return nil
        }
    }
}
