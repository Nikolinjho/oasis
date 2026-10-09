import Combine
import Foundation

/// Состояние явного подключения statusline для страницы настроек.
@MainActor
final class ClaudeConnection: ObservableObject {
  @Published private(set) var status: ClaudeStatuslineInstaller.Status = .notInstalled
  @Published private(set) var error: String?
  @Published private(set) var hasConnectionRecord = false
  private let installer: ClaudeStatuslineInstaller

  init(installer: ClaudeStatuslineInstaller) {
    self.installer = installer
    refresh()
  }

  func refresh() {
    status = installer.status()
    hasConnectionRecord = installer.hasConnectionRecord
  }

  func connect(text: Bool, preservePrevious: Bool = true) {
    perform { try installer.install(text: text, preservePrevious: preservePrevious) }
  }

  func disconnect() { perform { try installer.uninstall() } }
  func setText(_ text: Bool) { perform { try installer.setText(text) } }

  private func perform(_ action: () throws -> Void) {
    do {
      try action()
      error = nil
    } catch { self.error = error.localizedDescription }
    refresh()
  }
}
