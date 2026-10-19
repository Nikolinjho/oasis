import AppKit

extension AppDelegate {
  /// Повторный запуск (open -a, Spotlight) открывает настройки: с Hide menu bar icon при закрытой крышке
  /// иначе до них не добраться
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    settingsWindow.show()
    return false
  }

}
