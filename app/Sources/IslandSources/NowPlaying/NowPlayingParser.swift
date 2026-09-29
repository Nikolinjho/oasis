import Foundation
import IslandCore

public enum NowPlayingChange: Equatable, Sendable {
    case newTrack(NowPlayingInfo)
    case updated(NowPlayingInfo)
    case cleared
}

/// Разбор строк `mediaremote-adapter.pl stream --no-diff --micros`: каждая строка — полный payload.
/// С --micros время приходит в ключах *Micros; у stream нет --now, поэтому elapsed отсчитывается от timestampEpochMicros
public struct NowPlayingParser: Sendable {
    public private(set) var current: NowPlayingInfo?

    public init() {}

    private struct Line: Decodable {
        let type: String
        let payload: Payload?
    }

    private struct Payload: Decodable {
        let bundleIdentifier: String?
        let title: String?
        let artist: String?
        let album: String?
        let playing: Bool?
        let durationMicros: Double?
        let elapsedTimeMicros: Double?
        /// Есть только у `get --now`: оценка на момент вывода
        let elapsedTimeNowMicros: Double?
        /// Момент, к которому относится elapsedTimeMicros
        let timestampEpochMicros: Double?
        let artworkData: String?
        let prohibitsSkip: Bool?
        let shuffleMode: Int?
        let repeatMode: Int?
    }

    /// ignoringClear: пустой payload не сбрасывает текущий трек. Для первой строки перезапущенного адаптера:
    /// он всегда начинает с пустого payload, и без этого остров схлопывался бы и снова показывал peek
    public mutating func consume(_ line: String, now: Date = Date(), ignoringClear: Bool = false) -> NowPlayingChange? {
        guard let decoded = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
              decoded.type == "data" else { return nil }
        guard let payload = decoded.payload, let title = payload.title, !title.isEmpty else {
            guard current != nil, !ignoringClear else { return nil }
            current = nil
            return .cleared
        }
        let elapsed: (value: Double, at: Date)? =
            if let nowValue = payload.elapsedTimeNowMicros {
                (nowValue / 1_000_000, now)
            } else if let value = payload.elapsedTimeMicros {
                (value / 1_000_000, payload.timestampEpochMicros.map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? now)
            } else {
                nil
            }
        let info = NowPlayingInfo(
            bundleID: payload.bundleIdentifier,
            title: title,
            artist: payload.artist,
            album: payload.album,
            isPlaying: payload.playing ?? false,
            duration: payload.durationMicros.map { $0 / 1_000_000 },
            elapsed: elapsed?.value,
            elapsedAt: elapsed?.at ?? now,
            artwork: payload.artworkData.flatMap { Data(base64Encoded: $0) },
            canSkip: !(payload.prohibitsSkip ?? BrowserSources.contains(payload.bundleIdentifier)),
            isBrowser: BrowserSources.contains(payload.bundleIdentifier),
            shuffleMode: payload.shuffleMode,
            repeatMode: payload.repeatMode)
        let isNewTrack = current?.trackKey != info.trackKey
        current = info
        return isNewTrack ? .newTrack(info) : .updated(info)
    }
}
