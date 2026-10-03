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
          // AX 28.09: время прогресса стоит на одном y у Music и YouTube — квадратный слот 56×56
          // не даёт 56×31 обложке сжать строку и сдвинуть прогресс с кнопками вверх
          .frame(width: 56, height: 56)
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
        ForEach(
          Array(
            PlayerControl.row(info, extra: appearance.playerControl, outputSymbol: appearance.output.symbol)
              .enumerated()), id: \.offset
        ) { _, control in
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
        VolumeRow(level: volume, onAction: onAction)
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
/// Шаг считает система от сохранённого уровня (VolumeControl.rowStep): при mute level тут 0, а шагать надо не от него.
/// Цвет полоски — серый, как на кадре player-volume-row.jpg; толщина и кегль — оценка
struct VolumeRow: View {
  let level: Double
  let onAction: (PlayerAction) -> Void
  /// Пока палец на полоске — уровень под ним: полоска идёт за пальцем, даже когда система получает его реже
  @GestureState private var dragLevel: Double?
  /// setVolume не чаще 30 раз в секунду (оценка): каждый кадр жеста — лишний вызов CoreAudio и уведомление
  @State private var throttle = ValueThrottle<Double>(interval: 1.0 / 30)

  var body: some View {
    HStack(spacing: 10) {
      Button {
        onAction(.stepVolume(up: false))
      } label: {
        Image(systemName: "speaker.fill")
      }
      .buttonStyle(.plain)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(IslandPalette.foreground.opacity(0.2))
          Capsule()
            .fill(IslandPalette.secondary)
            .frame(width: proxy.size.width * min(max(dragLevel ?? level, 0), 1))
        }
        .frame(height: 5)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .updating($dragLevel) { value, state, _ in
              state = Self.level(at: value.location.x, width: proxy.size.width)
            }
            .onChanged { value in
              let level = Self.level(at: value.location.x, width: proxy.size.width)
              if let sent = throttle.offer(level, at: Date()) { onAction(.setVolume(sent)) }
            }
            // последний уровень доходит всегда, даже если его придержал троттлинг
            .onEnded { value in
              let level = Self.level(at: value.location.x, width: proxy.size.width)
              if let sent = throttle.finish(level) { onAction(.setVolume(sent)) }
            })
      }
      Button {
        onAction(.stepVolume(up: true))
      } label: {
        Image(systemName: "speaker.wave.2.fill")
      }
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
          .fill(fill(isPressed: configuration.isPressed))
      )
      // замера нет, оценка
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }

  private func fill(isPressed: Bool) -> Color {
    if isPressed { return IslandPalette.pressedActive }
    return isHovered ? IslandPalette.pressed : .clear
  }
}
