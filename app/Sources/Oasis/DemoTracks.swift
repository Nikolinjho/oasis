import AppKit
import IslandCore
import IslandSources

/// Фейковые треки для отладки и demo-прогона: однотонные обложки известного цвета
@MainActor
enum DemoTracks {
  // вычисляемые: static let заморозил бы elapsedAt в момент первого обращения, и трек сразу стал бы старым
  static var all: [NowPlayingInfo] {
    [
      make("Fire", color: NSColor(srgbRed: 0.95, green: 0.45, blue: 0.1, alpha: 1)),
      make("Water", color: NSColor(srgbRed: 0.2, green: 0.5, blue: 0.95, alpha: 1)),
    ]
  }

  /// Браузерный источник без обложки: в острове плейсхолдер ♪
  static var withoutArtwork: NowPlayingInfo {
    NowPlayingInfo(
      bundleID: "com.google.Chrome", title: "Fake Track Without Artwork", artist: "Demo Artist",
      isPlaying: true, duration: 200, elapsed: 10, elapsedAt: Date())
  }

  static func make(_ title: String, color: NSColor) -> NowPlayingInfo {
    let artwork = png(color)
    return NowPlayingInfo(
      bundleID: "dev.nikoko.oasis.demo", title: title, artist: "Demo Artist",
      isPlaying: true, duration: 200, elapsed: 30, elapsedAt: Date(),
      artwork: artwork, accent: artwork.flatMap(ArtworkColor.accent(of:)))
  }

  private static func png(_ color: NSColor) -> Data? {
    let image = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
      color.setFill()
      rect.fill()
      return true
    }
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
  }
}

/// Следующий демо-трек по кругу: общий для пунктов меню и сценариев
@MainActor
final class DemoTrackCursor {
  private var index = -1

  func next() -> NowPlayingInfo {
    index += 1
    return DemoTracks.all[index % DemoTracks.all.count]
  }
}
