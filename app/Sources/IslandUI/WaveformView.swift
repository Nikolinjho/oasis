import IslandCore
import SwiftUI

/// Цвет волны из обложки или нейтральный, если обложки нет
func accentColor(_ info: NowPlayingInfo?) -> Color {
    guard let accent = info?.accent else { return IslandPalette.secondary }
    return Color(accent)
}

/// Заливка волны по Now Playing → цвет. Gradient без второго цвета обложки — как Colored
func waveformFill(_ info: NowPlayingInfo?, _ style: WaveformStyle) -> AnyShapeStyle {
    switch style {
    case .monochrome:
        return AnyShapeStyle(IslandPalette.secondary)
    case .colored:
        return AnyShapeStyle(accentColor(info))
    case .gradient:
        guard let top = info?.accent, let bottom = info?.accentBottom else { return AnyShapeStyle(accentColor(info)) }
        // Alcove 1.7.9: переход слева направо между двумя цветами обложки (кадр style-gradient.jpg, 28.09)
        return AnyShapeStyle(LinearGradient(colors: [Color(top), Color(bottom)], startPoint: .leading, endPoint: .trailing))
    }
}

/// Заливка прогресса плеера: тот же стиль, что у волны (progressStyle у Alcove 1.7.9, 28.09)
func progressFill(_ info: NowPlayingInfo?, _ style: WaveformStyle) -> AnyShapeStyle {
    waveformFill(info, style)
}

/// Эквалайзер: 4 полоски 2 pt с зазором 1.5, у каждой свой период пульса (motion.md, «Справа: эквалайзер»)
struct WaveformView: View {
    let isPlaying: Bool
    let fill: AnyShapeStyle
    var maxHeight: CGFloat = 12

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.5) {
                ForEach(Array(IslandTiming.equalizerPeriods.enumerated()), id: \.offset) { _, period in
                    let phase = 0.5 - 0.5 * cos(2 * .pi * t / period)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fill)
                        .frame(width: 2, height: isPlaying ? 3 + (maxHeight - 3) * phase : 2)
                }
            }
            .frame(height: maxHeight)
            .animation(.easeOut(duration: 0.3), value: isPlaying)
        }
    }
}
