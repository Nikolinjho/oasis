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
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let settings: AppSettings
  private let claudeConnection: ClaudeConnection?
  private let playSound: (IslandSound) -> Void
  /// Календари EventKit для страницы Calendar: AppDelegate берёт их у источника календаря
  private let calendars: () -> [CalendarInfo]
  private var window: NSWindow?
  private var closeShortcutMonitor: Any?

  init(
    settings: AppSettings, claudeConnection: ClaudeConnection? = nil, calendars: @escaping () -> [CalendarInfo] = { [] },
    playSound: @escaping (IslandSound) -> Void = { _ in }
  ) {
    self.settings = settings
    self.claudeConnection = claudeConnection
    self.calendars = calendars
    self.playSound = playSound
    super.init()
  }

  func show() {
    let window = self.window ?? makeWindow()
    self.window = window
    // Dock-иконка живёт, пока открыты настройки; клик по ней вызывает applicationShouldHandleReopen
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    // Смена accessory → regular и закрытие меню могут завершиться после show и снова убрать окно
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window, self.window === window, NSApp.activationPolicy() == .regular else { return }
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    }
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }

  private func makeWindow() -> NSWindow {
    let window = SettingsWindow(
      contentRect: NSRect(x: 0, y: 0, width: 620, height: 659),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = SettingsPage.general.title
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentView = NSHostingView(
      rootView: SettingsView(
        settings: settings, claudeConnection: claudeConnection, playSound: playSound, calendars: calendars,
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
