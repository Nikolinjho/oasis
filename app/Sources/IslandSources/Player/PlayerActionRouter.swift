import IslandCore
import os

/// Исполнители кнопок плеера. Системные вызовы за этим протоколом, в тестах — фейк
@MainActor
public protocol PlayerActionPerforming: AnyObject {
    func send(_ command: MediaCommand)
    func favoriteInMusic()
    func activateApp(bundleID: String)
    func chooseOutput()
}

/// Решает, кому и с чем отдать действие кнопки плеера
@MainActor
public struct PlayerActionRouter {
    public nonisolated static let musicBundleID = "com.apple.Music"

    private let performer: any PlayerActionPerforming
    private let log = SourceLog.logger("player")

    public init(performer: any PlayerActionPerforming) {
        self.performer = performer
    }

    public func perform(_ action: PlayerAction, nowPlaying: NowPlayingInfo?) {
        switch action {
        case let .media(command):
            performer.send(command)
        case .favorite:
            // AppleScript бьёт в Music: при другом источнике отметили бы чужой трек или запустили Music
            guard nowPlaying?.bundleID == Self.musicBundleID else {
                log.info("favorite skipped: source is \(nowPlaying?.bundleID ?? "none", privacy: .public)")
                return
            }
            performer.favoriteInMusic()
        case .openSource:
            guard let bundleID = nowPlaying?.bundleID else {
                log.info("open source skipped: no bundle id")
                return
            }
            performer.activateApp(bundleID: bundleID)
        case .chooseOutput:
            performer.chooseOutput()
        }
    }
}
