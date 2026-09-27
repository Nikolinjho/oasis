import AppKit

/// Подменю Debug из разделов DebugCatalog. Галочки переключателей ставятся при каждом открытии
@MainActor
enum DebugMenu {
    static func item(sections: [DebugSection]) -> NSMenuItem {
        let root = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for section in sections {
            let item = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
            let submenu = RefreshingMenu()
            for entry in section.entries {
                switch entry {
                case .separator:
                    submenu.addItem(.separator())
                case let .action(action):
                    let menuItem = ClosureMenuItem(action.title) { action.perform() }
                    submenu.addItem(menuItem)
                    if let isOn = action.isOn { submenu.states.append((menuItem, isOn)) }
                }
            }
            item.submenu = submenu
            menu.addItem(item)
        }
        root.submenu = menu
        return root
    }
}

/// Меню, которое перед показом ставит галочки по текущему состоянию
@MainActor
final class RefreshingMenu: NSMenu, NSMenuDelegate {
    var states: [(NSMenuItem, @MainActor () -> Bool)] = []

    init() {
        super.init(title: "")
        delegate = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for (item, isOn) in states { item.state = isOn() ? .on : .off }
    }
}
