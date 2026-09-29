import IslandCore
import SwiftUI

/// Раскрытый плеер 345×175: верхние 32 pt — полоса menu bar под вырезом, контент ниже
struct PlayerView: View {
    let info: NowPlayingInfo?
    var appearance = IslandAppearance.default
    var volume: Double = 0
    var showsVolumeRow = false
    let onAction: (PlayerAction) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ArtworkFlip(info: info, side: 56, radius: 12, flips: appearance.artworkFlip)
                    .modifier(PausedArtwork(isPlaying: info?.isPlaying ?? false))
                    // Alcove 1.7.9: клик по обложке или названию выводит источник вперёд, остров не закрывается
                    .contentShape(Rectangle())
                    .onTapGesture { onAction(.openSource) }
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: appearance.title(for: info) ?? "Not Playing", shortAlignment: .leading, outdentsFade: true)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IslandPalette.foreground)
                        .frame(height: 18)
                    Text(info?.artist ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(IslandPalette.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { onAction(.openSource) }
                Spacer(minLength: 8)
                WaveformView(isPlaying: info?.isPlaying ?? false, fill: waveformFill(info, appearance.waveform), maxHeight: 16)
            }
            ProgressRow(
                info: info, fill: progressFill(info, appearance.waveform),
                showsRemaining: appearance.showsRemainingTime, onAction: onAction)
            // центры кнопок через 63 pt, крайние на ~73% ширины плеера, как на кадрах Alcove
            HStack(spacing: 15) {
                // id по месту в ряду: смена ⏸/▶ не пересоздаёт кнопку и не рвёт replace-переход
                ForEach(Array(PlayerControl.row(info, extra: appearance.playerControl, outputSymbol: appearance.output.symbol)
                    .enumerated()), id: \.offset) { _, control in
                    if let control {
                        let showsBackground = PlayerButton.showsBackground(control, showsVolumeRow: showsVolumeRow)
                        PlayerButton(control: control, showsBackground: showsBackground) { onAction(control.action) }
                    } else {
                        // пустой слот держит место: остальные кнопки не сдвигаются
                        Color.clear.frame(width: 48, height: 40)
                    }
                }
            }
            if showsVolumeRow {
                VolumeRow(level: volume) { onAction(.setVolume($0)) }
                    .padding(.horizontal, 4)
                    // строка открывается маской растущей формы, как контент при раскрытии
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 10)
    }
}

/// Строка громкости под кнопками плеера (Alcove 1.7.9, 28.09): 🔈 и 🔊 — шаг 10%, полоска — уровень по месту.
/// Цвет полоски — серый, как на кадре player-volume-row.jpg; толщина и кегль — оценка
struct VolumeRow: View {
    let level: Double
    let onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button { onChange(Self.stepped(level, up: false)) } label: { Image(systemName: "speaker.fill") }
                .buttonStyle(.plain)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(IslandPalette.foreground.opacity(0.2))
                    Capsule()
                        .fill(IslandPalette.secondary)
                        .frame(width: proxy.size.width * min(max(level, 0), 1))
                }
                .frame(height: 5)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    onChange(Self.level(at: value.location.x, width: proxy.size.width))
                })
            }
            Button { onChange(Self.stepped(level, up: true)) } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(.plain)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(IslandPalette.secondary)
        .frame(height: 18)
    }

    nonisolated static func level(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(min(max(x / width, 0), 1))
    }

    /// 🔈 и 🔊: ±10% (у Alcove 56 → 46 → 56)
    nonisolated static func stepped(_ level: Double, up: Bool) -> Double {
        min(max(level + (up ? 0.1 : -0.1), 0), 1)
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

    /// Масштаб 0.83 — замер Alcove 1.7.9 в Duo: 54×30 → 45×25 (28.09). Насыщенность и прозрачность — замера нет, оценка
    static func look(isPlaying: Bool) -> Look {
        isPlaying ? Look(scale: 1, saturation: 1, opacity: 1) : Look(scale: 0.83, saturation: 0.2, opacity: 0.6)
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
    var showsRemaining = true
    var onAction: (PlayerAction) -> Void = { _ in }
    /// Пока палец на полоске — позиция под ним в долях 0…1. @GestureState сам сбрасывается в nil,
    /// когда жест кончается или отменяется системой — руками очищать нечем и не нужно
    @GestureState private var dragFraction: Double?
    /// После отпускания — отправленный seek и момент отправки, пока источник не прислал новую позицию.
    /// Без этого полоска на 0.3–0.6 с отскакивала назад к старой info.position, а потом прыгала вперёд
    @State private var pendingSeek: (position: TimeInterval, at: Date)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = info?.duration ?? 0
            let position = Self.displayPosition(
                dragFraction: dragFraction, pendingSeek: pendingSeek,
                sourcePosition: info?.position(at: context.date) ?? 0, duration: duration,
                isPlaying: info?.isPlaying ?? false, now: context.date)
            HStack(spacing: 8) {
                Text(Self.format(position)).monospacedDigit()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(IslandPalette.foreground.opacity(0.2))
                        Capsule()
                            .fill(fill)
                            .frame(width: duration > 0 ? proxy.size.width * min(position / duration, 1) : 0)
                    }
                    .frame(height: 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .updating($dragFraction) { value, fraction, _ in
                            guard duration > 0 else { return }
                            fraction = Self.seekPosition(at: value.location.x, width: proxy.size.width, duration: duration) / duration
                        }
                        .onEnded { value in
                            guard duration > 0 else { return }
                            let seeked = Self.seekPosition(at: value.location.x, width: proxy.size.width, duration: duration)
                            pendingSeek = (seeked, Date())
                            onAction(.seek(seeked))
                        })
                }
                .frame(height: 14)
                Text(Self.trailing(position: position, duration: duration, remaining: showsRemaining))
                    .monospacedDigit()
                    .contentShape(Rectangle())
                    // Alcove 1.7.9, 28.09: клик по времени справа переключает остаток и полную длительность
                    .onTapGesture { onAction(.toggleTimeDisplay) }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(IslandPalette.secondary)
            .frame(height: 14)
            // источник подтвердил позицию своим payload — держать seek дальше незачем
            .onChange(of: info?.elapsedAt) { _, _ in pendingSeek = nil }
            // сменился трек — отложенный seek был про прошлый
            .onChange(of: info?.trackKey) { _, _ in pendingSeek = nil }
            // источник молчит дольше 1.5 с — оценка, не держим позицию вечно без подтверждения
            .onChange(of: context.date) { _, date in
                guard let pendingSeek, date.timeIntervalSince(pendingSeek.at) > 1.5 else { return }
                self.pendingSeek = nil
            }
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

    /// Справа от прогресса: «-m:ss» до конца или «m:ss» длительность (showRemainingTime у Alcove)
    nonisolated static func trailing(position: TimeInterval, duration: TimeInterval, remaining: Bool) -> String {
        remaining ? Self.remaining(position: position, duration: duration) : format(duration)
    }

    /// Точка клика/перетаскивания по полоске в позицию трека: за краями зажата в 0…duration
    nonisolated static func seekPosition(at x: CGFloat, width: CGFloat, duration: TimeInterval) -> TimeInterval {
        guard width > 0 else { return 0 }
        return duration * Double(min(max(x / width, 0), 1))
    }

    /// Что показать под позицией: перетаскивание — самое свежее, дальше — отложенный seek
    /// (свой отсчёт от at, пока играет), и только потом — позиция источника
    nonisolated static func displayPosition(
        dragFraction: Double?, pendingSeek: (position: TimeInterval, at: Date)?, sourcePosition: TimeInterval,
        duration: TimeInterval, isPlaying: Bool, now: Date
    ) -> TimeInterval {
        if let dragFraction { return dragFraction * duration }
        if let pendingSeek { return pendingSeek.position + (isPlaying ? now.timeIntervalSince(pendingSeek.at) : 0) }
        return sourcePosition
    }
}

/// Кнопка ряда управления: символ и действие. Крайние мельче и приглушённее центральных
struct PlayerControl: Equatable {
    let symbol: String
    let action: PlayerAction
    let isSide: Bool
    var isEnabled = true
    /// Shuffle или Repeat включён: подложка и точка под иконкой (Alcove 1.7.9, Shuffle у Music, 28.09)
    var isActive = false

    /// Доп. кнопка слева. nil — слот пустой: браузер, Copy (ссылки нет) и Favorite не у Music (AppleScript бьёт в Music)
    static func extra(_ info: NowPlayingInfo?, choice: PlayerExtraControl) -> PlayerControl? {
        guard let info, !info.isBrowser else { return nil }
        switch choice {
        case .shuffle:
            return PlayerControl(symbol: "shuffle", action: .toggleShuffle, isSide: true, isActive: info.isShuffling)
        case .repeat:
            return PlayerControl(
                symbol: info.repeatMode == 2 ? "repeat.1" : "repeat", action: .cycleRepeat, isSide: true,
                isActive: info.isRepeating)
        case .favorite:
            return info.bundleID == NowPlayingInfo.musicBundleID
                ? PlayerControl(symbol: "star.fill", action: .favorite, isSide: true) : nil
        case .copy:
            return nil
        }
    }

    /// Пять мест: слот пустой у браузера, но ⏪ ⏸ ⏩ и вывод не сдвигаются (у Alcove те же x, 28.09)
    static func row(
        _ info: NowPlayingInfo?, extra choice: PlayerExtraControl = .shuffle,
        outputSymbol: String = OutputDeviceKind.speakers.symbol
    ) -> [PlayerControl?] {
        let canSkip = info?.canSkip ?? true
        return [
            extra(info, choice: choice),
            PlayerControl(symbol: "backward.fill", action: .media(.previousTrack), isSide: false, isEnabled: canSkip),
            PlayerControl(
                symbol: info?.isPlaying == true ? "pause.fill" : "play.fill",
                action: .media(.togglePlayPause), isSide: false),
            PlayerControl(symbol: "forward.fill", action: .media(.nextTrack), isSide: false, isEnabled: canSkip),
            PlayerControl(symbol: outputSymbol, action: .toggleVolumeRow, isSide: true),
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
    /// Подсветка подложки: активный Shuffle/Repeat или открытая строка громкости у кнопки вывода.
    /// Точка под иконкой от этого не зависит — она только про control.isActive (см. overlay в body)
    var showsBackground = false
    let action: () -> Void
    @State private var isHovered = false

    /// Строка громкости подсвечивает только кнопку вывода; Shuffle/Repeat подсвечиваются своим состоянием
    static func showsBackground(_ control: PlayerControl, showsVolumeRow: Bool) -> Bool {
        control.isActive || (control.action == .toggleVolumeRow && showsVolumeRow)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: control.symbol)
                .font(.system(size: control.size, weight: .semibold))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
                // замера нет, оценка по кадрам паузы: ⏸ → ▶ за ~0.4 с
                .animation(.easeInOut(duration: 0.4), value: control.symbol)
                .frame(width: 48, height: 40)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    if control.isActive, control.isSide {
                        // точка под иконкой активного Shuffle, внутри подложки кнопки: оценка по кадру 28.09
                        Circle().fill(IslandPalette.secondary).frame(width: 3, height: 3).offset(y: -6)
                    }
                }
        }
        .buttonStyle(HoverBackgroundStyle(isHovered: (isHovered || showsBackground) && control.isEnabled))
        .onHover { isHovered = $0 }
        .disabled(!control.isEnabled)
    }

    /// Тусклая — неактивные ⏪⏩ у браузера (Alcove 1.7.9, 28.09)
    private var color: Color {
        guard control.isEnabled else { return IslandPalette.tertiary }
        return control.isSide ? IslandPalette.secondary : IslandPalette.foreground
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
