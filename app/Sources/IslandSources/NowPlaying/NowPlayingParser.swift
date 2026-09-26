import Foundation
import IslandCore

public enum NowPlayingChange: Equatable, Sendable {
    case newTrack(NowPlayingInfo)
    case updated(NowPlayingInfo)
    case cleared
}

/// Разбор строк `mediaremote-adapter.pl stream --no-diff --micros --now`: каждая строка — полный payload
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
        let duration: Double?
        let elapsedTime: Double?
        let elapsedTimeNow: Double?
        let artworkData: String?
    }

    public mutating func consume(_ line: String, now: Date = Date()) -> NowPlayingChange? {
        guard let decoded = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
              decoded.type == "data" else { return nil }
        guard let payload = decoded.payload, let title = payload.title, !title.isEmpty else {
            guard current != nil else { return nil }
            current = nil
            return .cleared
        }
        let info = NowPlayingInfo(
            bundleID: payload.bundleIdentifier,
            title: title,
            artist: payload.artist,
            album: payload.album,
            isPlaying: payload.playing ?? false,
            duration: payload.duration.map { $0 / 1_000_000 },
            elapsed: (payload.elapsedTimeNow ?? payload.elapsedTime).map { $0 / 1_000_000 },
            elapsedAt: now,
            artwork: payload.artworkData.flatMap { Data(base64Encoded: $0) })
        let isNewTrack = current?.trackKey != info.trackKey
        current = info
        return isNewTrack ? .newTrack(info) : .updated(info)
    }
}
