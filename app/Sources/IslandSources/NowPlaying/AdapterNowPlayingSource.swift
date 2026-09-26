import Foundation
import IslandCore
import os

public protocol NowPlayingSource: AnyObject, Sendable {
    var changes: AsyncStream<NowPlayingChange> { get }
    func start()
    func stop()
    func send(_ command: MediaCommand)
}

/// «Сейчас играет» через mediaremote-adapter: с macOS 15.4 MediaRemote отдаёт данные только процессам Apple,
/// а системный perl подписан Apple
public final class AdapterNowPlayingSource: NowPlayingSource, @unchecked Sendable {
    public let changes: AsyncStream<NowPlayingChange>
    private let continuation: AsyncStream<NowPlayingChange>.Continuation
    private let paths: AdapterPaths
    private let log = SourceLog.logger("now-playing")
    // всё изменяемое — под замком: колбэки Process приходят с чужих потоков, поэтому класс @unchecked Sendable
    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    private struct State {
        var process: Process?
        var parser = NowPlayingParser()
        var buffer = LineBuffer()
        var backoff = Backoff()
        var accents: [String: RGB] = [:]
        var stopped = false
    }

    public init(paths: AdapterPaths) {
        self.paths = paths
        (changes, continuation) = AsyncStream.makeStream()
    }

    public func start() {
        state.withLockUnchecked { $0.stopped = false }
        launch()
    }

    public func stop() {
        let process = state.withLockUnchecked { s -> Process? in
            s.stopped = true
            return s.process
        }
        process?.terminate()
    }

    public func send(_ command: MediaCommand) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [paths.script.path, paths.framework.path, "send", String(command.rawValue)]
        do {
            try process.run()
        } catch {
            log.error("send \(command.rawValue) failed: \(error.localizedDescription)")
        }
    }

    private func launch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        // у stream нет --now: elapsed парсер отсчитывает от timestampEpochMicros
        process.arguments = [paths.script.path, paths.framework.path, "stream", "--no-diff", "--micros", "--debounce=50"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard let self, !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self.receive(chunk)
        }
        process.terminationHandler = { [weak self] finished in
            self?.log.error("adapter exited with status \(finished.terminationStatus)")
            self?.scheduleRestart()
        }
        state.withLockUnchecked { s in
            s.process = process
            // хвост недописанной строки от умершего процесса не должен приклеиться к первой строке нового
            s.buffer = LineBuffer()
        }
        do {
            try process.run()
            log.info("adapter started")
        } catch {
            log.error("adapter launch failed: \(error.localizedDescription)")
            scheduleRestart()
        }
    }

    private func receive(_ chunk: Data) {
        let changes = state.withLockUnchecked { s -> [NowPlayingChange] in
            s.buffer.append(chunk).compactMap { line in
                guard let change = s.parser.consume(line) else { return nil }
                s.backoff.reset()
                return change
            }
        }
        for change in changes {
            continuation.yield(withAccent(change))
        }
    }

    private func withAccent(_ change: NowPlayingChange) -> NowPlayingChange {
        switch change {
        case let .newTrack(info): .newTrack(fillAccent(info))
        case let .updated(info): .updated(fillAccent(info))
        case .cleared: .cleared
        }
    }

    /// Цвет считаем один раз на трек: адаптер присылает обложку в каждой строке
    private func fillAccent(_ info: NowPlayingInfo) -> NowPlayingInfo {
        var info = info
        let key = info.trackKey
        if let cached = state.withLockUnchecked({ $0.accents[key] }) {
            info.accent = cached
        } else if let artwork = info.artwork, let color = ArtworkColor.accent(of: artwork) {
            state.withLockUnchecked { $0.accents[key] = color }
            info.accent = color
        }
        return info
    }

    private func scheduleRestart() {
        let delay: Duration? = state.withLockUnchecked { s in
            s.process = nil
            return s.stopped ? nil : s.backoff.next()
        }
        guard let delay else { return }
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.launch()
        }
    }
}
