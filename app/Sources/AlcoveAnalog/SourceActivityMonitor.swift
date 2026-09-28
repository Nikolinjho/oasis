import AppKit

/// Какое приложение на переднем плане: для Hide while source app is active. Сообщает bundle id при каждой активации
@MainActor
final class SourceActivityMonitor {
    private let onChange: (String?) -> Void
    private var token: NSObjectProtocol?

    init(onChange: @escaping (String?) -> Void) {
        self.onChange = onChange
    }

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            MainActor.assumeIsolated { self?.onChange(bundleID) }
        }
        onChange(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }
}
