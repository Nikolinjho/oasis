import Foundation
import IslandCore

/// Исполнители кнопок плеера. Системные вызовы за этим протоколом, в тестах — фейк
@MainActor
public protocol PlayerActionPerforming: AnyObject {
  func send(_ command: MediaCommand)
  func favoriteInMusic()
  func setFavorite(to favorite: Bool, expectedTrackID: String)
  func activateApp(bundleID: String)
  func setVolume(_ level: Double)
  func stepVolume(up: Bool)
  func setShuffle(_ mode: Int)
  func setRepeat(_ mode: Int)
  func seek(to position: TimeInterval)
  func seek(to position: TimeInterval, expectedTrackID: String)
}

/// Решает, кому и с чем отдать действие кнопки плеера
@MainActor
public struct PlayerActionRouter {
  private let performer: any PlayerActionPerforming

  public init(performer: any PlayerActionPerforming) { self.performer = performer }

  /// false — команда недоступна, оптимистичное состояние менять нельзя
  @discardableResult
  // swiftlint:disable:next cyclomatic_complexity - таблица команд с отдельными проверками возможностей
  public func perform(_ action: PlayerAction, nowPlaying info: NowPlayingInfo?) -> Bool {
    switch action {
    case .media(let command):
      if let capabilities = info?.capabilities {
        let supported =
          switch command {
          case .play, .pause, .togglePlayPause: capabilities.canPlayPause
          case .nextTrack: capabilities.canNext
          case .previousTrack: capabilities.canPrevious
          }
        guard supported else { return false }
      }
      performer.send(command)
    case .favorite:
      guard let info, info.capabilities.canFavorite else { return false }
      if info.bundleID == YandexMusicClient.bundleID {
        guard let id = info.sourceTrackID, let favorite = info.isFavorite else { return false }
        performer.setFavorite(to: !favorite, expectedTrackID: id)
      } else {
        guard info.bundleID == NowPlayingInfo.musicBundleID else { return false }
        performer.favoriteInMusic()
      }
    case .openSource:
      guard let bundleID = info?.bundleID else { return false }
      performer.activateApp(bundleID: bundleID)
    case .toggleVolumeRow, .toggleTimeDisplay:
      return false
    case .setVolume(let level): performer.setVolume(level)
    case .stepVolume(let up): performer.stepVolume(up: up)
    case .toggleShuffle:
      guard let mode = info?.nextSupportedShuffleMode else { return false }
      performer.setShuffle(mode)
    case .cycleRepeat:
      guard let mode = info?.nextSupportedRepeatMode else { return false }
      performer.setRepeat(mode)
    case .seekTrack(let position, let expectedTrackID):
      guard position.isFinite, let info, info.capabilities.canSeek,
        info.bundleID == YandexMusicClient.bundleID,
        info.sourceTrackID == expectedTrackID
      else { return false }
      performer.seek(to: position, expectedTrackID: expectedTrackID)
    case .seek(let position):
      guard position.isFinite, info?.capabilities.canSeek != false else { return false }
      if info?.bundleID == YandexMusicClient.bundleID {
        guard let id = info?.sourceTrackID else { return false }
        performer.seek(to: position, expectedTrackID: id)
      } else {
        performer.seek(to: position)
      }
    }
    return true
  }
}
