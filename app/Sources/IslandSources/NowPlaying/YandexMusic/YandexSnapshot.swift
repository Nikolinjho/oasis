import Foundation
import IslandCore

struct YandexSnapshot: Decodable, Sendable {
  var version: Int
  var state: String
  var sampledAt: Double
  var trackID: String?
  var title: String?
  var artist: String?
  var album: String?
  var isPlaying: Bool?
  var duration: Double?
  var position: Double?
  var artworkURL: String?
  var isFavorite: Bool?
  var shuffleMode: Int?
  var repeatMode: Int?
  var capabilities: Capabilities?

  struct Capabilities: Decodable, Sendable {
    var canPlayPause: Bool
    var canNext: Bool
    var canPrevious: Bool
    var canSeek: Bool
    var canFavorite: Bool
    var shuffleModes: [Int]
    var repeatModes: [Int]
  }

  var info: NowPlayingInfo? {
    guard version == 1, state == "ready", let trackID, !trackID.isEmpty,
      let title, !title.isEmpty, let isPlaying, let caps = capabilities, sampledAt.isFinite
    else { return nil }
    return NowPlayingInfo(
      bundleID: YandexMusicClient.bundleID, title: title, artist: artist, album: album,
      isPlaying: isPlaying, duration: duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
      elapsed: position.flatMap { $0.isFinite ? max(0, $0) : nil },
      elapsedAt: Date(timeIntervalSince1970: sampledAt), canSkip: caps.canNext || caps.canPrevious,
      shuffleMode: shuffleMode, repeatMode: repeatMode,
      capabilities: PlayerCapabilities(
        canPlayPause: caps.canPlayPause, canNext: caps.canNext, canPrevious: caps.canPrevious,
        canSeek: caps.canSeek, canFavorite: caps.canFavorite && isFavorite != nil,
        shuffleModes: caps.shuffleModes.filter { [1, 3].contains($0) },
        repeatModes: caps.repeatModes.filter { [1, 2, 3].contains($0) }, requiresConfirmation: true),
      sourceTrackID: trackID, isFavorite: isFavorite)
  }
}
