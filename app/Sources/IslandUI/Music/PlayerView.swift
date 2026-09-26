import IslandCore
import SwiftUI

/// Раскрытый плеер 370×175: верхние 32 pt — полоса menu bar под вырезом, контент ниже
struct PlayerView: View {
    let info: NowPlayingInfo?
    let onCommand: (MediaCommand) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ArtworkFlip(info: info, side: 56, radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info?.title ?? "Not Playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IslandPalette.foreground)
                    Text(info?.artist ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(IslandPalette.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                WaveformView(isPlaying: info?.isPlaying ?? false, color: IslandUI.accentColor(info), maxHeight: 16)
            }
            ProgressRow(info: info)
            HStack(spacing: 28) {
                PlayerButton(symbol: "backward.fill") { onCommand(.previousTrack) }
                PlayerButton(symbol: info?.isPlaying == true ? "pause.fill" : "play.fill", size: 22) { onCommand(.togglePlayPause) }
                PlayerButton(symbol: "forward.fill") { onCommand(.nextTrack) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 12)
    }
}

struct ProgressRow: View {
    let info: NowPlayingInfo?

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
                            .fill(IslandPalette.foreground)
                            .frame(width: duration > 0 ? proxy.size.width * position / duration : 0)
                    }
                }
                .frame(height: 4)
                Text(Self.format(duration)).monospacedDigit()
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
}

struct PlayerButton: View {
    let symbol: String
    var size: CGFloat = 18
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(IslandPalette.foreground)
                .frame(width: 44, height: 32)
        }
        .buttonStyle(PressedBackgroundStyle())
    }
}

/// У нажатой кнопки скруглённая подложка #1C1C1E, как в записи Alcove
struct PressedBackgroundStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? IslandPalette.pressed : .clear))
    }
}
