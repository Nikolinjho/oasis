import AppKit
import ServiceManagement

@MainActor
enum LoginItem {
  static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

  /// Саму ошибку не показывает: вызывающий решает, как (сайдшит на своём окне или runModal),
  /// и вызывает не из Binding-сеттера напрямую, а обёрнутым в Task, чтобы не блокировать SwiftUI
  static func toggle() throws {
    if isEnabled {
      try SMAppService.mainApp.unregister()
    } else {
      try SMAppService.mainApp.register()
    }
  }

  /// При ad-hoc подписи регистрация не проходит: показываем причину, а не молчим.
  /// Есть окно рядом — сайдшит на нём, иначе обычный runModal
  static func presentError(_ error: Error, on window: NSWindow?) {
    let alert = NSAlert()
    alert.messageText = "Launch at Login"
    alert.informativeText = error.localizedDescription
    if let window {
      alert.beginSheetModal(for: window)
    } else {
      alert.runModal()
    }
  }
}
