import IslandCore
import SwiftUI

/// HUD громкости и яркости живёт в строке menu bar: высота 32, растёт только в ширину до 367
struct HUDView: View {
    let kind: HUDKind
    let level: Double
    let notchWidth: CGFloat
    var appearance = HUDAppearance(style: .white)
    /// Глиф устройства вывода для Show device (IslandAppearance.output)
    var deviceSymbol: String? = nil

    var body: some View {
        // Оба крыла зашиты в вырез напрямую, а не через Spacer(minLength:): иначе запас слева
        // (короткая подпись) утекал направо и «100%» заезжал под камеру (ревью задачи 6, 28.09)
        let wing = Self.wingWidth(notchWidth: notchWidth)
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: Self.iconSymbol(kind, level, appearance, deviceSymbol: deviceSymbol))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .contentTransition(.symbolEffect(.replace))
                if !appearance.hidesLabel {
                    Text(kind == .volume ? "Sound" : "Display")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(IslandPalette.foreground)
            .frame(width: wing, alignment: .leading)
            Color.clear.frame(width: notchWidth)
            HStack(spacing: 6) {
                if appearance.showsPercentage {
                    Text(Self.percent(level))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(IslandPalette.foreground)
                }
                LevelBar(level: level, style: appearance.style, speed: appearance.speed)
                    .frame(width: Self.barWidth(appearance, wing: wing), height: 5)
            }
            .frame(width: wing, alignment: .trailing)
        }
        // Шрифт 13, отступ иконки 6, ширина иконки 18, паддинг 14, полоска 64×5:
        // не мерили, подогнано по capture/analysis/states/t69.4.png. Итоговая ширина 367 не зависит
        // от текущей (анимирующейся) формы: контент маскируется формой острова, как и раньше
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

    /// Show device: глиф устройства вывода вместо уровня. Без звука — перечёркнутый динамик, как в Show symbol
    nonisolated static func iconSymbol(_ kind: HUDKind, _ level: Double, _ appearance: HUDAppearance, deviceSymbol: String?) -> String {
        guard kind == .volume, appearance.icon == .device, level > 0, let deviceSymbol else { return symbol(kind, level) }
        return deviceSymbol
    }

    /// Крыло от края паддинга до тела HUD: тело растёт вместе с вырезом на ту же величину (задача 1,
    /// IslandGeometry.notchRelativeWidth), поэтому крыло не зависит от notchWidth — всегда
    /// (367 − 183) / 2 − паддинг 14 = 78 pt
    nonisolated static func wingWidth(notchWidth: CGFloat) -> CGFloat {
        let total = IslandGeometry.notchRelativeWidth(IslandGeometry.hud.width, notch: notchWidth)
        return max(0, (total - notchWidth) / 2 - 14)
    }

    /// С процентом полоска уже, чтобы «100%» + зазор 6 + полоска не выходили за крыло.
    /// 36 — замер NSFont 12pt semibold monospacedDigit «100%» ≈ 35.6 pt, округлено вверх
    nonisolated static func barWidth(_ appearance: HUDAppearance, wing: CGFloat) -> CGFloat {
        appearance.showsPercentage ? max(16, min(40, wing - 36 - 6)) : min(64, wing)
    }

    nonisolated static func percent(_ level: Double) -> String {
        "\(Int((min(max(level, 0), 1) * 100).rounded()))%"
    }
}

public struct LevelBar: View {
    let level: Double
    var style = HUDBarStyle.white
    var speed = HUDSpeed.fast

    public init(level: Double, style: HUDBarStyle = .white, speed: HUDSpeed = .fast) {
        self.level = level
        self.style = style
        self.speed = speed
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: proxy.size.width * clamped)
                    .shadow(color: glow, radius: glow == .clear ? 0 : 3)
            }
        }
        .animation(speed.levelAnimation, value: level)
    }

    private var clamped: Double { min(max(level, 0), 1) }

    // цвета Accent, Glow и свечение Decibel — замера нет, оценка по плиткам настроек (settings-05, settings-06)
    private var track: Color {
        switch style {
        case .white: IslandPalette.foreground.opacity(0.2)
        case .accent: IslandPalette.dateAccent.opacity(0.25)
        case .decibel: Color(HUDBarStyle.decibelTrack)
        case .glow: IslandPalette.foreground.opacity(0.15)
        }
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .white: AnyShapeStyle(IslandPalette.foreground)
        case .accent: AnyShapeStyle(IslandPalette.dateAccent)
        case .decibel: AnyShapeStyle(Color(HUDBarStyle.decibelColor(level: clamped)))
        case .glow: AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.6), .white], startPoint: .leading, endPoint: .trailing))
        }
    }

    private var glow: Color {
        switch style {
        case .white, .accent: .clear
        case .decibel: Color(HUDBarStyle.decibelColor(level: clamped)).opacity(0.7)
        case .glow: .white.opacity(0.6)
        }
    }
}

extension HUDSpeed {
    /// Smooth и Instant — замера нет, оценка. Fast — прежняя 0.2 с (подогнано по t69.4.png)
    var levelAnimation: Animation? {
        switch self {
        case .smooth: .smooth(duration: 0.35)
        case .fast: .smooth(duration: 0.2)
        case .instant: nil
        }
    }
}
