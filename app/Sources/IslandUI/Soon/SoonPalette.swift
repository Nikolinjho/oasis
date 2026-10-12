import AppKit
import IslandCore
import SwiftUI

/// Акцент из иконки Soon, цвета удаления из CSS оригинального приложения.
public enum SoonPalette {
  public static let accent = Color(ActivityLayouts.soonAccent)
  public static let darkCoral = Color(red: 255 / 255, green: 129 / 255, blue: 107 / 255)
  public static let foreground = Color.white
  public static let secondary = Color.white.opacity(0.5)

  public static let coral = Color(
    nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(red: 255 / 255, green: 129 / 255, blue: 107 / 255, alpha: 1)
        : NSColor(red: 255 / 255, green: 84 / 255, blue: 84 / 255, alpha: 1)
    })
}
