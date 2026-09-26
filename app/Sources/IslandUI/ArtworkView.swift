import AppKit
import SwiftUI

/// Обложка трека. У браузерных источников её нет: тогда ♪ на тёмно-сером квадрате
struct ArtworkView: View {
    let artwork: Data?
    let side: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let artwork, let image = NSImage(data: artwork) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    IslandPalette.placeholder
                    Text("♪")
                        .font(.system(size: side * 0.5, weight: .semibold))
                        .foregroundStyle(IslandPalette.secondary)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
