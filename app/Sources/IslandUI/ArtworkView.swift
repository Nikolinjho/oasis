import AppKit
import SwiftUI

/// Обложка трека. У браузерных источников её нет: тогда ♪ на тёмно-сером квадрате
struct ArtworkView: View {
  let artwork: Data?
  let side: CGFloat
  let radius: CGFloat

  var body: some View {
    let image = artwork.flatMap { NSImage(data: $0) }
    let size = Self.frame(for: image, side: side)
    Group {
      if let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          IslandPalette.placeholder
          Text("♪")
            .font(.system(size: side * 0.5, weight: .semibold))
            .foregroundStyle(IslandPalette.secondary)
        }
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
  }

  /// Рамка обложки: ширина side, у широкой картинки (видео) высота по 16:9, как у Alcove
  /// (54×30 в Duo, 56×31 в плеере, 28.09). Порог 1.3 отделяет 16:9 и 4:3 от почти квадратных обложек — оценка
  nonisolated static func frame(for artwork: Data?, side: CGFloat) -> CGSize {
    frame(for: artwork.flatMap { NSImage(data: $0) }, side: side)
  }

  private nonisolated static func frame(for image: NSImage?, side: CGFloat) -> CGSize {
    guard let image, image.size.height > 0, image.size.width / image.size.height >= 1.3 else {
      return CGSize(width: side, height: side)
    }
    return CGSize(width: side, height: (side * 9 / 16).rounded())
  }
}
