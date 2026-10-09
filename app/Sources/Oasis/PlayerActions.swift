import AppKit
import IslandCore
import IslandSources
import os

/// Системные исполнители кнопок плеера. Что кому отдать, решает PlayerActionRouter
@MainActor
final class PlayerActions: PlayerActionPerforming {
  /// Источник берётся в момент нажатия: Source в настройках меняют на лету (NowPlayingSourceSwitcher)
  private let currentSource: () -> (any NowPlayingSource)?
  private var source: (any NowPlayingSource)? { currentSource() }
  private let favorite = MusicFavorite()
  private let nowPlaying: () -> NowPlayingInfo?
  /// Громкость появляется позже кнопок (startLevels после startPlayerActions): берём её в момент нажатия
  private let volume: () -> VolumeControl?
  /// Строка громкости сменила уровень: AppDelegate кладёт его в store и глушит HUD
  private let onRowVolume: (Double) -> Void
  private let log = Logger(subsystem: "dev.nikoko.oasis", category: "player")

  init(
    source: @escaping () -> (any NowPlayingSource)?, nowPlaying: @escaping () -> NowPlayingInfo?, volume: @escaping () -> VolumeControl?,
    onRowVolume: @escaping (Double) -> Void
  ) {
    currentSource = source
    self.nowPlaying = nowPlaying
    self.volume = volume
    self.onRowVolume = onRowVolume
  }

  func send(_ command: MediaCommand) {
    guard let source else {
      log.error("media command \(command.rawValue) dropped: no now playing source")
      return
    }
    source.send(command)
  }

  func favoriteInMusic() {
    favorite.favoriteCurrentTrack()
  }

  func setFavorite(to favorite: Bool, expectedTrackID: String) {
    guard let source = source as? any YandexSourceControlling,
      nowPlaying()?.bundleID == YandexMusicClient.bundleID,
      nowPlaying()?.sourceTrackID == expectedTrackID
    else { return }
    source.setFavorite(to: favorite, expectedTrackID: expectedTrackID)
  }

  func seek(to position: TimeInterval, expectedTrackID: String) {
    guard let source = source as? any YandexSourceControlling,
      nowPlaying()?.bundleID == YandexMusicClient.bundleID,
      nowPlaying()?.sourceTrackID == expectedTrackID
    else { return }
    source.seek(to: position, expectedTrackID: expectedTrackID)
  }

  func activateApp(bundleID: String) {
    log.info("open source \(bundleID, privacy: .public)")
    AppActivator.activate(bundleID: bundleID)
  }

  /// Уровень по месту на строке. setVolumeUnmuted снимает mute — иначе VolumeState.level снаружи остался бы 0,
  /// и store.volumeLevel тут же откатился бы к нулю на первом же уведомлении CoreAudio о смене громкости
  func setVolume(_ level: Double) {
    guard let volume = volume() else { return }
    volume.setVolumeUnmuted(level)
    onRowVolume(level)
  }

  /// 🔈/🔊: шаг от сохранённого уровня и при mute, как у клавиши (VolumeControl.rowStep)
  func stepVolume(up: Bool) {
    guard let volume = volume() else { return }
    onRowVolume(volume.rowStep(up: up))
  }

  func setShuffle(_ mode: Int) {
    source?.setShuffle(mode)
  }

  func setRepeat(_ mode: Int) {
    source?.setRepeat(mode)
  }

  func seek(to position: TimeInterval) {
    source?.seek(to: position)
  }
}
