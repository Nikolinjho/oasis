import IslandCore
import SwiftUI

/// Смена трека: старая обложка поворачивается до ребра, на ребре подменяется размытой новой,
/// та доворачивается и проявляется (capture/analysis/README.md, «Смена трека: 3D-переворот обложки»)
struct ArtworkFlip: View {
    let info: NowPlayingInfo?
    let side: CGFloat
    let radius: CGFloat

    @State private var shown: NowPlayingInfo?
    @State private var angle: Double = 0
    @State private var blur: CGFloat = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        ArtworkView(artwork: (shown ?? info)?.artwork, side: side, radius: radius)
            .blur(radius: blur)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .onAppear { shown = info }
            .onChange(of: info?.trackKey) { _, _ in flip() }
            .onChange(of: info?.artwork) { _, _ in
                // обложка у того же трека догрузилась позже: подменяем без переворота
                if shown?.trackKey == info?.trackKey { shown = info }
            }
    }

    private func flip() {
        guard shown != nil else {
            shown = info
            return
        }
        Task { @MainActor in
            withAnimation(.easeIn(duration: 0.12)) { angle = 90 }
            try? await Task.sleep(for: .milliseconds(120))
            shown = info
            angle = -90
            blur = 20
            scale = 1.08
            withAnimation(.easeOut(duration: 0.13)) { angle = 0 }
            withAnimation(.easeOut(duration: 0.4)) {
                blur = 0
                scale = 1
            }
        }
    }
}
