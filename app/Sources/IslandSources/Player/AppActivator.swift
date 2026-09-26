import AppKit
import os

/// Выводит вперёд приложение, откуда играет звук
@MainActor
public enum AppActivator {
    private nonisolated static let log = SourceLog.logger("player")

    /// openApplication, а не NSRunningApplication.activate: фоновому LSUIElement-приложению
    /// macOS 14+ отказывает в активации чужого, а открытие через Workspace проходит как клик в Dock.
    /// Запущенное приложение просто выходит вперёд, незапущенное запускается
    public static func activate(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            log.error("no application for \(bundleID, privacy: .public)")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { log.error("open \(bundleID, privacy: .public) failed: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
