import IslandCore
import SwiftUI

/// Live activity музыки: компакт 257×32, в peek снизу добавляется бегущая строка с названием
struct MusicLiveView: View {
    let info: NowPlayingInfo?
    let notchWidth: CGFloat
    let showsTitle: Bool
    var appearance = IslandAppearance.default

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // радиус 4: замера нет, оценка
                ArtworkFlip(info: info, side: 16, radius: 4, flips: appearance.artworkFlip)
                    // пауза — 0.85 от центра, отдельно от peek-масштаба, иначе на паузе обложку ещё и сносит к левому верху
                    .scaleEffect(isPlaying ? 1 : 0.85)
                    // peek — ×1.2 от левого верха (motion.md)
                    .scaleEffect(showsTitle ? IslandTiming.peekArtworkScale : 1, anchor: UnitPoint(x: 0.2, y: 0))
                    .opacity(isPlaying ? 1 : 0.6)
                    .animation(.easeOut(duration: 0.5), value: isPlaying)
                Spacer(minLength: notchWidth)
                if appearance.compactWaveform {
                    WaveformView(isPlaying: isPlaying, fill: waveformFill(info, appearance.waveform))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)

            if showsTitle {
                MarqueeText(text: Self.titleLine(info, title: appearance.title(for: info)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IslandPalette.foreground.opacity(0.85))
                    .frame(height: 16)
                    .padding(.horizontal, 14)
                    .transition(.slot)
            }
        }
    }

    private var isPlaying: Bool { info?.isPlaying ?? false }

    /// Формат из motion.md: «♪ Название ∙ Артист». title — что показываем (Hide media title extras чистит его
    /// снаружи, через appearance.title(for:)); сам info и его trackKey не трогаем — от них зависит ArtworkFlip
    nonisolated static func titleLine(_ info: NowPlayingInfo?, title: String? = nil) -> String {
        guard let info else { return "" }
        let title = title ?? info.title
        guard let artist = info.artist, !artist.isEmpty else { return "♪ \(title)" }
        return "♪ \(title) ∙ \(artist)"
    }
}
