import AppKit
import IslandCore
import IslandSources
import os

/// Системные исполнители кнопок плеера. Что кому отдать, решает PlayerActionRouter
@MainActor
final class PlayerActions: PlayerActionPerforming {
    private weak var source: (any NowPlayingSource)?
    private let favorite = MusicFavorite()
    private let outputs = OutputDevices()
    private let showMenu: (NSMenu) -> Void
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "player")

    init(source: (any NowPlayingSource)?, showMenu: @escaping (NSMenu) -> Void) {
        self.source = source
        self.showMenu = showMenu
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

    func chooseOutput() {
        let menu = OutputMenu.make(devices: outputs)
        // после выхода из действия кнопки SwiftUI: popUp крутит свой цикл событий до закрытия меню
        Task { @MainActor [showMenu] in showMenu(menu) }
    }
}
