import AppKit
import IslandCore
import IslandSources
import os

/// Системные исполнители кнопок плеера. Что кому отдать, решает PlayerActionRouter
@MainActor
final class PlayerActions: PlayerActionPerforming {
  private weak var source: (any NowPlayingSource)?
  private let favorite = MusicFavorite()
  /// Громкость появляется позже кнопок (startLevels после startPlayerActions): берём её в момент нажатия
  private let volume: () -> VolumeControl?
  /// Строка громкости сменила уровень: AppDelegate кладёт его в store и глушит HUD
  private let onRowVolume: (Double) -> Void
  private let log = Logger(subsystem: "dev.nikoko.oasis", category: "player")

  init(
    source: (any NowPlayingSource)?, volume: @escaping () -> VolumeControl?, onRowVolume: @escaping (Double) -> Void
  ) {
    self.source = source
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
