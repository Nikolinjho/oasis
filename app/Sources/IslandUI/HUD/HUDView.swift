import IslandCore
import SwiftUI

/// HUD громкости и яркости живёт в строке menu bar: высота 32, растёт только в ширину до 367
struct HUDView: View {
    let kind: HUDKind
    let level: Double
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: Self.symbol(kind, level))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(kind == .volume ? "Sound" : "Display")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(IslandPalette.foreground)
            Spacer(minLength: notchWidth)
            LevelBar(level: level)
                .frame(width: 64, height: 5)
        }
        // Шрифт 13, отступ иконки 6, ширина иконки 18, паддинг 14, полоска 64×5:
        // не мерили, подогнано по capture/analysis/states/t69.4.png, уточняется в задаче 16
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    nonisolated static func symbol(_ kind: HUDKind, _ level: Double) -> String {
        switch kind {
        case .brightness:
            level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            level == 0 ? "speaker.slash.fill"
                : level < 0.34 ? "speaker.wave.1.fill"
                : level < 0.67 ? "speaker.wave.2.fill"
                : "speaker.wave.3.fill"
        }
    }
}

struct LevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(IslandPalette.foreground.opacity(0.2))
                Capsule()
                    .fill(IslandPalette.foreground)
                    .frame(width: proxy.size.width * min(max(level, 0), 1))
            }
        }
        // Длительность 0.2 с: не мерили, подогнано по capture/analysis/states/t69.4.png, уточняется в задаче 16
        .animation(.smooth(duration: 0.2), value: level)
    }
}
