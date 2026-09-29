import AppKit
import IslandCore
import IslandSources
import os

/// Системные исполнители кнопок плеера. Что кому отдать, решает PlayerActionRouter
@MainActor
final class PlayerActions: PlayerActionPerforming {
    private weak var source: (any NowPlayingSource)?
    private let favorite = MusicFavorite()
    private let setVolumeLevel: (Double) -> Void
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "player")

    init(source: (any NowPlayingSource)?, setVolume: @escaping (Double) -> Void) {
        self.source = source
        self.setVolumeLevel = setVolume
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

    func setVolume(_ level: Double) {
        setVolumeLevel(level)
    }
}
