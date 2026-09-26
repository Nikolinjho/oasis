import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private var window: IslandWindowController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = IslandWindowController(store: store)
        statusItem = StatusItemController(
            debugItems: DebugMenu.items(store: store),
            isTrusted: { Permissions.isAccessibilityTrusted })
    }
}
