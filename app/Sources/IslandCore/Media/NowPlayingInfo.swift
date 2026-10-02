import Foundation

public struct RGB: Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

/// Команды плеера. Значения — коды `mediaremote-adapter.pl send`
public enum MediaCommand: Int, Sendable {
  case play = 0
  case pause = 1
  case togglePlayPause = 2
  case nextTrack = 4
  case previousTrack = 5
}

/// Действие кнопки раскрытого плеера. Медиакоманды уходят в адаптер, остальное исполняет приложение
public enum PlayerAction: Equatable, Sendable {
  case media(MediaCommand)
  /// Доп. кнопка у Apple Music, выбор Favorite: ⭐ «в избранное»
  case favorite
  /// Клик по обложке или названию: вывести источник на передний план (Alcove 1.7.9, 28.09)
  case openSource
  /// Кнопка вывода справа: показать или спрятать строку громкости (Alcove 1.7.9: меню устройств нет)
  case toggleVolumeRow
  /// Строка громкости: уровень 0…1 текущего выхода
  case setVolume(Double)
  /// Доп. кнопка Shuffle: включить или выключить перемешивание
  case toggleShuffle
  /// Доп. кнопка Repeat: следующий режим по кругу
  case cycleRepeat
  /// Клик по времени справа от прогресса: остаток ↔ длительность (Alcove 1.7.9, 28.09)
  case toggleTimeDisplay
  /// Клик или перетаскивание по прогрессу: позиция в секундах
  case seek(TimeInterval)
}

public struct NowPlayingInfo: Equatable, Sendable {
  public var bundleID: String?
  public var title: String
  public var artist: String?
  public var album: String?
  public var isPlaying: Bool
  public var duration: TimeInterval?
  public var elapsed: TimeInterval?
  /// Когда снято elapsed: от этого момента считается прогресс
  public var elapsedAt: Date
  /// PNG или JPEG обложки как есть
  public var artwork: Data?
  /// Цвет волны из обложки, считается в IslandSources
  public var accent: RGB?
  /// Цвет низа обложки для волны и прогресса Gradient: горизонтальный переход слева направо между
  /// accent и accentBottom (поправка 29.09 по Alcove 1.7.9, кадр style-gradient.jpg)
  public var accentBottom: RGB?
  /// Источник умеет переключать треки: иначе ⏪⏩ тусклые (у Alcove у браузера, 28.09)
  public var canSkip: Bool
  /// Источник — браузер: у Alcove нет слота доп. кнопки (28.09)
  public var isBrowser: Bool
  /// Коды MediaRemote из адаптера: 1 — выкл, 2 — альбомы, 3 — треки. Коды — по MRMediaRemote, проверить в Task 17
  public var shuffleMode: Int?
  /// 1 — выкл, 2 — один трек, 3 — все (пример адаптера: «repeat 3 — playlist»)
  public var repeatMode: Int?

  /// Favorite работает через AppleScript к Music: у других источников кнопки нет
  public static let musicBundleID = "com.apple.Music"

  public var isShuffling: Bool { (shuffleMode ?? 1) > 1 }
  public var isRepeating: Bool { (repeatMode ?? 1) > 1 }

  /// Repeat по кругу, как в Music: выкл → все → один → выкл
  public static func nextRepeatMode(after mode: Int?) -> Int {
    switch mode {
    case 3: 2
    case 2: 1
    default: 3
    }
  }

  public init(
    bundleID: String? = nil, title: String, artist: String? = nil, album: String? = nil,
    isPlaying: Bool, duration: TimeInterval? = nil, elapsed: TimeInterval? = nil,
    elapsedAt: Date = Date(), artwork: Data? = nil, accent: RGB? = nil, accentBottom: RGB? = nil,
    canSkip: Bool = true, isBrowser: Bool = false, shuffleMode: Int? = nil, repeatMode: Int? = nil
  ) {
    self.bundleID = bundleID
    self.title = title
    self.artist = artist
    self.album = album
    self.isPlaying = isPlaying
    self.duration = duration
    self.elapsed = elapsed
    self.elapsedAt = elapsedAt
    self.artwork = artwork
    self.accent = accent
    self.accentBottom = accentBottom
    self.canSkip = canSkip
    self.isBrowser = isBrowser
    self.shuffleMode = shuffleMode
    self.repeatMode = repeatMode
  }

  /// По нему решаем, сменился ли трек (переворот обложки, peek)
  public var trackKey: String { [title, artist ?? "", album ?? ""].joined(separator: "|") }

  /// Текущая позиция с учётом времени, прошедшего с elapsedAt
  public func position(at now: Date) -> TimeInterval? {
    guard let elapsed else { return nil }
    let value = isPlaying ? elapsed + now.timeIntervalSince(elapsedAt) : elapsed
    guard let duration else { return value }
    return min(value, duration)
  }
}
