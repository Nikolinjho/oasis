import IslandCore
import SwiftUI

/// Live activity музыки: компакт 261×32, в peek снизу добавляется бегущая строка с названием
struct MusicLiveView: View {
    let info: NowPlayingInfo?
    let notchWidth: CGFloat
    let showsTitle: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // радиус 4: замера нет, оценка
                ArtworkFlip(info: info, side: 16, radius: 4)
                    .scaleEffect(isPlaying ? 1 : 0.85)
                    .opacity(isPlaying ? 1 : 0.6)
                    .animation(.easeOut(duration: 0.5), value: isPlaying)
                Spacer(minLength: notchWidth)
                WaveformView(isPlaying: isPlaying, color: IslandUI.accentColor(info))
            }
            .padding(.horizontal, 12)
            .frame(height: 32)

            if showsTitle {
                MarqueeText(text: Self.titleLine(info))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IslandPalette.foreground.opacity(0.85))
                    .frame(height: 16)
                    .padding(.horizontal, 14)
                    .transition(.slot)
            }
        }
    }

    private var isPlaying: Bool { info?.isPlaying ?? false }

    /// Формат из motion.md: «♪ Название ∙ Артист»
    nonisolated static func titleLine(_ info: NowPlayingInfo?) -> String {
        guard let info else { return "" }
        guard let artist = info.artist, !artist.isEmpty else { return "♪ \(info.title)" }
        return "♪ \(info.title) ∙ \(artist)"
    }
}
