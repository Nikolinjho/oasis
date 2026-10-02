import AppKit

/// LSUIElement-приложение без Dock-иконки: без строки в Info.plist меню бара нет и не будет,
/// но NSApp.mainMenu — не то же самое: NSApplication.sendEvent(_:) ищет ⌘-эквиваленты
/// (⌘W, ⌘Q, стандартные правки) сначала в нём. Пустой mainMenu — часть путей их не находит вовсе,
/// поэтому у окна настроек нет привычного ⌘W. Меню показывается только пока приложение активно
/// (открыто окно настроек): для accessory-приложения это ожидаемо и безвредно
enum MainMenu {
  static func build() -> NSMenu {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    appMenuItem.submenu = appMenu
    appMenu.addItem(
      NSMenuItem(
        title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

    return mainMenu
  }
}
