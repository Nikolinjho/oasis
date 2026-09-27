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
    private let launchAtLogin = ClosureMenuItem("Launch at Login") { LoginItem.toggle() }
    private let grantAccessibility = ClosureMenuItem("Grant Accessibility…") { Permissions.openAccessibilitySettings() }
    private let isTrusted: () -> Bool

    init(debugItem: NSMenuItem, isTrusted: @escaping () -> Bool) {
        self.isTrusted = isTrusted
        super.init()
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Alcove Analog")
        // позиция после перетаскивания с Cmd сохраняется между запусками
        item.autosaveName = "AlcoveAnalogStatus"

        menu.delegate = self
        menu.addItem(launchAtLogin)
        menu.addItem(grantAccessibility)
        menu.addItem(.separator())

        menu.addItem(debugItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLogin.state = LoginItem.isEnabled ? .on : .off
        grantAccessibility.isHidden = isTrusted()
    }
}
