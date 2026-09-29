import AppKit
import Foundation
import IslandCore
import os

/// «В избранное» текущему треку Apple Music через AppleScript.
/// MediaRemote тут не помогает: адаптер пропускает только команды 0…13, а LikeTrack — 21
public final class MusicFavorite: Sendable {
    enum Outcome: Equatable {
        case done
        case notAuthorized
        case failed(String)
    }

    static let script = """
        with timeout of 5 seconds
            tell application id "\(NowPlayingInfo.musicBundleID)" to set favorited of current track to true
        end timeout
        """

    private let log = SourceLog.logger("favorite")

    public init() {}

    /// Асинхронно: osascript ждёт ответа Music и, в первый раз, решения пользователя в запросе Apple Events
    public func favoriteCurrentTrack() {
        // не запускаем Music ради избранного, если его уже закрыли
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: NowPlayingInfo.musicBundleID).isEmpty else {
            log.info("favorite skipped: Music is not running")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", Self.script]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { [log] process in
            let text = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            switch Self.outcome(status: process.terminationStatus, stderr: text) {
            case .done: log.info("favorited current Music track")
            case .notAuthorized: log.error("favorite: no Apple Events permission for Music")
            case let .failed(message): log.error("favorite failed: \(message, privacy: .public)")
            }
        }
        do {
            try process.run()
        } catch {
            log.error("osascript failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func outcome(status: Int32, stderr: String) -> Outcome {
        if status == 0 { return .done }
        // errAEEventNotPermitted: отказ или ещё не выданное разрешение Automation
        if stderr.contains("(-1743)") { return .notAuthorized }
        return .failed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
