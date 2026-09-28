import AppKit

/// Пункт меню с замыканием вместо target-action
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    @objc private func fire() {
        handler()
    }
}

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    /// То же меню открывается правым кликом по острову: компакт закрывает иконку в menu bar
    let menu = NSMenu()
    private let launchAtLogin = ClosureMenuItem("Launch at Login") {
        Task { @MainActor in
            do {
                try LoginItem.toggle()
            } catch {
                // окна настроек тут нет: обычный runModal
                LoginItem.presentError(error, on: nil)
            }
        }
    }
    private let grantAccessibility = ClosureMenuItem("Grant Accessibility…") { Permissions.openAccessibilitySettings() }
    private let isTrusted: () -> Bool
    private let calendarItems: () -> [NSMenuItem]
    /// Пункты события, вставленные при прошлом открытии: снимаются перед пересборкой
    private var shownCalendarItems: [NSMenuItem] = []

    init(
        debugItem: NSMenuItem, isTrusted: @escaping () -> Bool, openSettings: @escaping () -> Void,
        calendarItems: @escaping () -> [NSMenuItem] = { [] }
    ) {
        self.isTrusted = isTrusted
        self.calendarItems = calendarItems
        super.init()
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Alcove Analog")
        // позиция после перетаскивания с Cmd сохраняется между запусками
        item.autosaveName = "AlcoveAnalogStatus"

        menu.delegate = self
        menu.addItem(ClosureMenuItem("Settings…", key: ",") { openSettings() })
        menu.addItem(launchAtLogin)
        menu.addItem(grantAccessibility)
        menu.addItem(.separator())

        menu.addItem(debugItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    /// Hide menu bar icon: NSStatusItem остаётся живым, меню по-прежнему открывается правым кликом по острову
    func setIconHidden(_ hidden: Bool) {
        item.isVisible = !hidden
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLogin.state = LoginItem.isEnabled ? .on : .off
        grantAccessibility.isHidden = isTrusted()
        rebuildCalendarItems()
    }

    /// Пункты события вверху меню, как у Alcove. Пересобираются при каждом открытии: правый клик по острову
    /// открывает это же меню, поэтому пункты есть и там
    private func rebuildCalendarItems() {
        for item in shownCalendarItems { menu.removeItem(item) }
        let items = calendarItems()
        shownCalendarItems = items.isEmpty ? [] : items + [.separator()]
        for (index, item) in shownCalendarItems.enumerated() { menu.insertItem(item, at: index) }
    }
}
