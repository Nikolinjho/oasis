import IslandCore
import SwiftUI

/// Прогресс плеера: время слева, полоска с перемоткой, остаток или длительность справа
struct ProgressRow: View {
  let info: NowPlayingInfo?
  var fill: AnyShapeStyle = AnyShapeStyle(IslandPalette.foreground)
  var showsRemaining = true
  var onAction: (PlayerAction) -> Void = { _ in }
  /// Пока палец на полоске — позиция под ним в долях 0…1. @GestureState сам сбрасывается в nil,
  /// когда жест кончается или отменяется системой — руками очищать нечем и не нужно
  @GestureState private var dragFraction: Double?
  /// После отпускания — отправленный seek и момент отправки, пока источник не пришёл к цели (holdsSeek).
  /// Без этого полоска на 0.3–0.6 с отскакивала назад к старой info.position, а потом прыгала вперёд
  @State private var seekGesture = SeekGesture()
  @State private var pendingSeek: (position: TimeInterval, at: Date)?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      let duration = info?.duration ?? 0
      let position = Self.displayPosition(
        dragFraction: seekGesture.belongs(to: info) ? dragFraction : nil, pendingSeek: pendingSeek,
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
          .gesture(
            DragGesture(minimumDistance: 0)
              .updating($dragFraction) { value, fraction, _ in
                guard Self.canSeek(info), duration > 0 else { return }
                fraction = Self.seekPosition(at: value.location.x, width: proxy.size.width, duration: duration) / duration
              }
              .onChanged { _ in seekGesture.begin(info) }
              .onEnded { value in
                guard Self.canSeek(info), duration > 0 else { return }
                let seeked = Self.seekPosition(at: value.location.x, width: proxy.size.width, duration: duration)
                guard let action = seekGesture.finish(at: seeked, current: info) else { return }
                pendingSeek = Self.holdsPendingSeek(info) ? (seeked, Date()) : nil
                onAction(action)
              }, including: Self.canSeek(info) ? .all : .none)
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
      // новый payload: отпускаем seek, только если источник пришёл к цели. YouTube может
      // переопубликовать позицию до перемотки — сброс на любой payload отбрасывал полоску назад
      .onChange(of: info?.elapsedAt) { _, _ in
        guard let pendingSeek, let info else { return }
        let now = Date()
        let target = Self.displayPosition(
          dragFraction: nil, pendingSeek: pendingSeek, sourcePosition: 0, duration: info.duration ?? 0,
          isPlaying: info.isPlaying, now: now)
        if !Self.holdsSeek(target: target, sourcePosition: info.position(at: now) ?? 0, sentAt: pendingSeek.at, now: now) {
          self.pendingSeek = nil
        }
      }
      // сменился трек — отложенный seek был про прошлый
      .onChange(of: info?.trackKey) { _, _ in pendingSeek = nil }
      .onChange(of: dragFraction == nil) { _, ended in
        if ended { seekGesture = SeekGesture() }
      }
    }
    // источник так и не подтвердил — не держим цель вечно (holdsSeek, тот же таймаут)
    .task(id: pendingSeek?.at) {
      guard let sentAt = pendingSeek?.at else { return }
      try? await Task.sleep(for: .seconds(Self.seekHoldTimeout))
      guard !Task.isCancelled, pendingSeek?.at == sentAt else { return }
      pendingSeek = nil
    }
  }

  nonisolated static func canSeek(_ info: NowPlayingInfo?) -> Bool {
    info?.capabilities.canSeek == true && (info?.duration ?? 0) > 0
  }

  nonisolated static func holdsPendingSeek(_ info: NowPlayingInfo?) -> Bool {
    canSeek(info) && info?.capabilities.requiresConfirmation != true
  }

  /// Допуск, в котором позиция источника считается подтверждением seek, и сколько ждать подтверждения (оценки)
  nonisolated static let seekTolerance: TimeInterval = 1.5
  nonisolated static let seekHoldTimeout: TimeInterval = 3

  /// Держать ли отправленный seek после нового payload: да, пока источник не пришёл к цели и не вышел таймаут
  nonisolated static func holdsSeek(target: TimeInterval, sourcePosition: TimeInterval, sentAt: Date, now: Date) -> Bool {
    guard now.timeIntervalSince(sentAt) < seekHoldTimeout else { return false }
    return abs(sourcePosition - target) > seekTolerance
  }

  /// m:ss, а от часа и дальше — h:mm:ss (подкасты и видео идут дольше 60 минут, «75:12» не читается)
  nonisolated static func format(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds).rounded(.down))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    guard hours > 0 else { return String(format: "%d:%02d", minutes, secs) }
    return String(format: "%d:%02d:%02d", hours, minutes, secs)
  }

  /// Справа от прогресса, как в Alcove: «-m:ss» до конца трека, «-h:mm:ss» для долгих.
  /// Считается от уже округлённой позиции, чтобы сумма двух подписей всегда давала длительность
  nonisolated static func remaining(position: TimeInterval, duration: TimeInterval) -> String {
    "-" + format(duration - max(0, position).rounded(.down))
  }

  /// Справа от прогресса: «-m:ss»/«-h:mm:ss» до конца или длительность целиком (showRemainingTime у Alcove)
  nonisolated static func trailing(position: TimeInterval, duration: TimeInterval, remaining: Bool) -> String {
    remaining ? Self.remaining(position: position, duration: duration) : format(duration)
  }

  /// Точка клика/перетаскивания по полоске в позицию трека: за краями зажата в 0…duration
  nonisolated static func seekPosition(at x: CGFloat, width: CGFloat, duration: TimeInterval) -> TimeInterval {
    guard width > 0 else { return 0 }
    return duration * Double(min(max(x / width, 0), 1))
  }

  /// Что показать под позицией: перетаскивание — самое свежее, дальше — отложенный seek
  /// (свой отсчёт от at, пока играет), и только потом — позиция источника. Зажато в 0…duration:
  /// отсчёт отложенного seek у конца трека иначе уводил бы остаток в минус
  nonisolated static func displayPosition(  // swiftlint:disable:this function_parameter_count - чистая функция от состояния
    dragFraction: Double?, pendingSeek: (position: TimeInterval, at: Date)?, sourcePosition: TimeInterval,
    duration: TimeInterval, isPlaying: Bool, now: Date
  ) -> TimeInterval {
    let position =
      if let dragFraction {
        dragFraction * duration
      } else if let pendingSeek {
        pendingSeek.position + (isPlaying ? now.timeIntervalSince(pendingSeek.at) : 0)
      } else {
        sourcePosition
      }
    return duration > 0 ? min(max(position, 0), duration) : max(position, 0)
  }
}

/// Жест перемотки относится к треку, на котором начался
struct SeekGesture {
  private var originKey: String?
  private var originTrackID: String?
  private var isYandex = false

  mutating func begin(_ info: NowPlayingInfo?) {
    guard originKey == nil, let info else { return }
    originKey = info.trackKey
    originTrackID = info.sourceTrackID
    isYandex = info.bundleID == "ru.yandex.desktop.music"
  }

  func belongs(to info: NowPlayingInfo?) -> Bool {
    originKey != nil && originKey == info?.trackKey
  }

  mutating func finish(at position: TimeInterval, current info: NowPlayingInfo?) -> PlayerAction? {
    defer { self = SeekGesture() }
    guard belongs(to: info), info?.capabilities.canSeek == true else { return nil }
    if isYandex {
      guard let id = originTrackID else { return nil }
      return .seekTrack(position, expectedTrackID: id)
    }
    return .seek(position)
  }
}
