import Foundation

/// Оптимистичный Shuffle/Repeat: клик сразу меняет показанный режим, не дожидаясь payload (200–500 мс).
/// Без этого второй быстрый клик считал бы от старого состояния и отменял первый
public struct PlaybackModeOverride: Equatable, Sendable {
  /// Режим, отправленный источнику, и у какого источника и когда
  public struct Pending: Equatable, Sendable {
    public let mode: Int
    public let bundleID: String?
    public let at: Date
  }

  /// Сколько ждать подтверждения от источника, который режим присылает: дальше верим payload (оценка)
  public static let timeout: TimeInterval = 2

  public private(set) var shuffle: Pending?
  public private(set) var repeatMode: Pending?

  public init() {}

  /// info — то, что показано сейчас (уже с override): от него и считается следующий режим
  public mutating func toggleShuffle(_ info: NowPlayingInfo, at now: Date) {
    guard let mode = info.nextSupportedShuffleMode else { return }
    shuffle = Pending(mode: mode, bundleID: info.bundleID, at: now)
  }

  public mutating func cycleRepeat(_ info: NowPlayingInfo, at now: Date) {
    guard let mode = info.nextSupportedRepeatMode else { return }
    repeatMode = Pending(mode: mode, bundleID: info.bundleID, at: now)
  }

  /// Отказ команды снимает ожидание соответствующего режима
  public mutating func clear(_ action: PlayerAction) {
    switch action {
    case .toggleShuffle: shuffle = nil
    case .cycleRepeat: repeatMode = nil
    default: break
    }
  }

  /// Показанное: режимы источника, поверх — ещё не подтверждённые клики
  public func applied(to info: NowPlayingInfo) -> NowPlayingInfo {
    var info = info
    if let shuffle, info.capabilities.shuffleModes.contains(shuffle.mode) { info.shuffleMode = shuffle.mode }
    if let repeatMode, info.capabilities.repeatModes.contains(repeatMode.mode) { info.repeatMode = repeatMode.mode }
    return info
  }

  /// Новый payload или таймер: снять подтверждённое, просроченное и чужого источника.
  /// System без поля (nil) сохраняет локальное состояние. Яндекс требует подтверждения и при nil
  public mutating func reconcile(with info: NowPlayingInfo, now: Date) {
    shuffle = Self.kept(
      shuffle, reported: info.shuffleMode, info: info, modes: info.capabilities.shuffleModes, now: now)
    repeatMode = Self.kept(
      repeatMode, reported: info.repeatMode, info: info, modes: info.capabilities.repeatModes, now: now
    )
  }

  /// Клик или таймер, без нового payload: снять только просроченное. Подтверждение засчитывает лишь
  /// reconcile — payload после клика. Иначе двойной клик назад к режиму старого payload снял бы override
  /// сразу, и ответ источника на первый клик мигнул бы на кнопке
  public mutating func expire(for info: NowPlayingInfo, now: Date) {
    shuffle = Self.unexpired(shuffle, reported: info.shuffleMode, requiresConfirmation: info.capabilities.requiresConfirmation, now: now)
    repeatMode = Self.unexpired(
      repeatMode, reported: info.repeatMode, requiresConfirmation: info.capabilities.requiresConfirmation, now: now)
  }

  /// Когда снять override по таймауту, если payload так и не подтвердит. nil — таймер не нужен
  public func nextExpiry(for info: NowPlayingInfo) -> Date? {
    [(shuffle, info.shuffleMode), (repeatMode, info.repeatMode)]
      .compactMap { pending, reported in
        reported == nil && !info.capabilities.requiresConfirmation ? nil : pending?.at.addingTimeInterval(Self.timeout)
      }
      .min()
  }

  private static func kept(_ pending: Pending?, reported: Int?, info: NowPlayingInfo, modes: [Int], now: Date)
    -> Pending?
  {
    guard let pending, pending.bundleID == info.bundleID, modes.contains(pending.mode), reported != pending.mode else { return nil }
    return unexpired(pending, reported: reported, requiresConfirmation: info.capabilities.requiresConfirmation, now: now)
  }

  private static func unexpired(_ pending: Pending?, reported: Int?, requiresConfirmation: Bool, now: Date) -> Pending? {
    guard let pending else { return nil }
    if reported == nil && !requiresConfirmation { return pending }
    return now.timeIntervalSince(pending.at) < timeout ? pending : nil
  }
}
