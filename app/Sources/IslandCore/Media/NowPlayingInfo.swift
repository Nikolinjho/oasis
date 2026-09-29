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
    /// Левая кнопка у Apple Music: ⭐ «в избранное»
    case favorite
    /// Левая кнопка у остальных источников: 🔗 открыть приложение, откуда играет звук
    case openSource
    /// Правая кнопка 💻: выбор устройства вывода звука
    case chooseOutput
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
    /// Цвет низа обложки для волны Gradient (motion.md: «вертикальный градиент из двух цветов обложки»)
    public var accentBottom: RGB?

    public init(
        bundleID: String? = nil, title: String, artist: String? = nil, album: String? = nil,
        isPlaying: Bool, duration: TimeInterval? = nil, elapsed: TimeInterval? = nil,
        elapsedAt: Date = Date(), artwork: Data? = nil, accent: RGB? = nil, accentBottom: RGB? = nil
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
