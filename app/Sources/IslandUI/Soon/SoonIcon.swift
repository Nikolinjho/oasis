import AppKit
import SwiftUI

/// Оригинальная цветная иконка Soon из icon.icns.
public struct SoonIcon: View {
  public init() {}

  public var body: some View {
    Group {
      if let image = Self.image {
        Image(nsImage: image)
          .renderingMode(.original)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "clock.arrow.circlepath")
          .resizable()
          .scaledToFit()
          .foregroundStyle(SoonPalette.accent)
      }
    }
    .accessibilityHidden(true)
  }

  private static let image: NSImage? = {
    guard let url = Bundle.main.resourceURL?.appendingPathComponent("Soon/Icon.png") else { return nil }
    return NSImage(contentsOf: url)
  }()
}
