import AppKit
import ApplicationServices

@MainActor
enum Permissions {
  static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

  /// Добавляет приложение в список Accessibility и показывает системный запрос
  static func requestAccessibility() {
    // строка вместо kAXTrustedCheckOptionPrompt: глобальная переменная C не concurrency-safe
    _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
  }

  static func openAccessibilitySettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }
}
