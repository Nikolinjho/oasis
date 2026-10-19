import AppKit
import SwiftUI

/// Оригинальный знак Codex из сохранённого SVG, без перерисовки.
public struct CodexIcon: View {
  public init() {}

  public var body: some View {
    Image(nsImage: Self.image)
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .accessibilityHidden(true)
  }

  private static let image: NSImage = {
    guard let url = Bundle.main.resourceURL?.appendingPathComponent("Codex/Icon.png"), let image = NSImage(contentsOf: url) else {
      return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
    }
    return image
  }()
}
