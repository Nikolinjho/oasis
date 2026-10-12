import AppKit
import IslandCore
import SwiftUI

/// Логотип из бандла с запасным SF Symbol: ресурсы сторонних приложений могут отсутствовать.
struct ActivityIcon: View {
  let layout: ActivityLayout

  var body: some View {
    Group {
      if layout.imageName == "soon" {
        SoonIcon()
      } else if let name = layout.imageName, let image = IconLibrary.image(named: name) {
        Image(nsImage: image)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: layout.symbol)
          .font(.system(size: 14, weight: .semibold))
      }
    }
    .foregroundStyle(Color(layout.symbolColor))
    .frame(width: 18, height: 15)
  }
}

enum IconLibrary {
  nonisolated static func url(named name: String, resources: URL?) -> URL? {
    resources?.appendingPathComponent("Icons").appendingPathComponent("\(name).png")
  }

  @MainActor
  static func image(named name: String) -> NSImage? {
    guard let url = url(named: name, resources: Bundle.main.resourceURL), let image = NSImage(contentsOf: url) else { return nil }
    image.isTemplate = true
    return image
  }
}
