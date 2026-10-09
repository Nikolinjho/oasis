import Foundation
import IslandCore

public enum NowPlayingSourceState: Equatable, Sendable {
  case appNotFound, appClosed, requiresConnection, connecting, connected, notReady, incompatibleVersion
  case failed(String)
  case commandFailed(PlayerAction, String)
}

public protocol YandexSourceControlling: NowPlayingSource {
  var statuses: AsyncStream<NowPlayingSourceState> { get }
  func seek(to position: TimeInterval, expectedTrackID: String)
  func setFavorite(to favorite: Bool, expectedTrackID: String)
}
