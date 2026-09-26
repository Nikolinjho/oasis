import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private var window: IslandWindowController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = StatusItemController(
            debugItems: DebugMenu.items(store: store),
            isTrusted: { Permissions.isAccessibilityTrusted })
        self.statusItem = statusItem
        window = IslandWindowController(store: store, menu: statusItem.menu)
    }
}
