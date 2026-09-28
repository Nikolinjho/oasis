import IslandCore
import SwiftUI

/// Цвет волны из обложки или нейтральный, если обложки нет
func accentColor(_ info: NowPlayingInfo?) -> Color {
    guard let accent = info?.accent else { return IslandPalette.secondary }
    return Color(accent)
}

/// Эквалайзер: 4 полоски 2 pt с зазором 1.5, у каждой свой период пульса (motion.md, «Справа: эквалайзер»)
struct WaveformView: View {
    let isPlaying: Bool
    let color: Color
    var maxHeight: CGFloat = 12

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.5) {
                ForEach(Array(IslandTiming.equalizerPeriods.enumerated()), id: \.offset) { _, period in
                    let phase = 0.5 - 0.5 * cos(2 * .pi * t / period)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 2, height: isPlaying ? 3 + (maxHeight - 3) * phase : 2)
                }
            }
            .frame(height: maxHeight)
            .animation(.easeOut(duration: 0.3), value: isPlaying)
        }
    }
}
