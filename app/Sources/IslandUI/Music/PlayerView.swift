import IslandCore
import SwiftUI

/// Раскрытый плеер 345×175: верхние 32 pt — полоса menu bar под вырезом, контент ниже
struct PlayerView: View {
    let info: NowPlayingInfo?
    var appearance = IslandAppearance.default
    let onAction: (PlayerAction) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ArtworkFlip(info: info, side: 56, radius: 12, flips: appearance.artworkFlip)
                    .modifier(PausedArtwork(isPlaying: info?.isPlaying ?? false))
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: info?.title ?? "Not Playing", shortAlignment: .leading, outdentsFade: true)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IslandPalette.foreground)
                        .frame(height: 18)
                    Text(info?.artist ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(IslandPalette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                WaveformView(isPlaying: info?.isPlaying ?? false, fill: waveformFill(info, appearance.waveform), maxHeight: 16)
            }
            ProgressRow(info: info, fill: progressFill(info, appearance.waveform))
            // центры кнопок через 63 pt, крайние на ~73% ширины плеера, как на кадрах Alcove
            HStack(spacing: 15) {
                // id по месту в ряду: смена ⏸/▶ не пересоздаёт кнопку и не рвёт replace-переход
                ForEach(Array(PlayerControl.row(info).enumerated()), id: \.offset) { _, control in
                    PlayerButton(control: control) { onAction(control.action) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 10)
    }
}

/// На паузе обложка уменьшается и выцветает, при play возвращается (кадры паузы Alcove)
struct PausedArtwork: ViewModifier {
    struct Look: Equatable {
        let scale: CGFloat
        let saturation: Double
        let opacity: Double
    }

    let isPlaying: Bool

    /// Масштаб 0.9 по кадрам; насыщенность и прозрачность — замера нет, оценка
    static func look(isPlaying: Bool) -> Look {
        isPlaying ? Look(scale: 1, saturation: 1, opacity: 1) : Look(scale: 0.9, saturation: 0.2, opacity: 0.6)
    }

    func body(content: Content) -> some View {
        let look = Self.look(isPlaying: isPlaying)
        content
            .saturation(look.saturation)
            .opacity(look.opacity)
            .scaleEffect(look.scale)
            // замера нет, оценка: в ногу со сменой ⏸/▶
            .animation(.easeInOut(duration: 0.4), value: isPlaying)
    }
}

struct ProgressRow: View {
    let info: NowPlayingInfo?
    var fill: AnyShapeStyle = AnyShapeStyle(IslandPalette.foreground)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = info?.position(at: context.date) ?? 0
            let duration = info?.duration ?? 0
            HStack(spacing: 8) {
                Text(Self.format(position)).monospacedDigit()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(IslandPalette.foreground.opacity(0.2))
                        Capsule()
                            .fill(fill)
                            .frame(width: duration > 0 ? proxy.size.width * position / duration : 0)
                    }
                }
                .frame(height: 4)
                Text(Self.remaining(position: position, duration: duration)).monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(IslandPalette.secondary)
            .frame(height: 14)
        }
    }

    nonisolated static func format(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Справа от прогресса, как в Alcove: «-m:ss» до конца трека.
    /// Считается от уже округлённой позиции, чтобы сумма двух подписей всегда давала длительность
    nonisolated static func remaining(position: TimeInterval, duration: TimeInterval) -> String {
        "-" + format(duration - max(0, position).rounded(.down))
    }
}

/// Кнопка ряда управления: символ и действие. Крайние мельче и приглушённее центральных
struct PlayerControl: Equatable {
    let symbol: String
    let action: PlayerAction
    let isSide: Bool

    /// ⭐ «в избранное» есть только у Apple Music, у остальных источников 🔗 открыть приложение
    static func leading(_ info: NowPlayingInfo?) -> PlayerControl {
        info?.bundleID == "com.apple.Music"
            ? PlayerControl(symbol: "star.fill", action: .favorite, isSide: true)
            : PlayerControl(symbol: "link", action: .openSource, isSide: true)
    }

    static func row(_ info: NowPlayingInfo?) -> [PlayerControl] {
        [
            leading(info),
            PlayerControl(symbol: "backward.fill", action: .media(.previousTrack), isSide: false),
            PlayerControl(
                symbol: info?.isPlaying == true ? "pause.fill" : "play.fill",
                action: .media(.togglePlayPause), isSide: false),
            PlayerControl(symbol: "forward.fill", action: .media(.nextTrack), isSide: false),
            PlayerControl(symbol: "laptopcomputer", action: .chooseOutput, isSide: true),
        ]
    }

    /// Пауза крупнее перемоток; размеры по пропорциям кадров, замера нет
    var size: CGFloat {
        switch action {
        case .media(.togglePlayPause): 24
        case .media: 19
        default: 16
        }
    }
}

struct PlayerButton: View {
    let control: PlayerControl
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: control.symbol)
                .font(.system(size: control.size, weight: .semibold))
                .foregroundStyle(control.isSide ? IslandPalette.secondary : IslandPalette.foreground)
                .contentTransition(.symbolEffect(.replace))
                // замера нет, оценка по кадрам паузы: ⏸ → ▶ за ~0.4 с
                .animation(.easeInOut(duration: 0.4), value: control.symbol)
                .frame(width: 48, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverBackgroundStyle(isHovered: isHovered))
        .onHover { isHovered = $0 }
    }
}

/// Скруглённая подложка #1C1C1E, пока курсор над кнопкой; при нажатии чуть ярче
struct HoverBackgroundStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill(isPressed: configuration.isPressed)))
            // замера нет, оценка
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private func fill(isPressed: Bool) -> Color {
        if isPressed { return IslandPalette.pressedActive }
        return isHovered ? IslandPalette.pressed : .clear
    }
}
