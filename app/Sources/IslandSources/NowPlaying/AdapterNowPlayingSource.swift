import Foundation
import IslandCore
import os

public protocol NowPlayingSource: AnyObject, Sendable {
    var changes: AsyncStream<NowPlayingChange> { get }
    func start()
    func stop()
    func send(_ command: MediaCommand)
    func setShuffle(_ mode: Int)
    func setRepeat(_ mode: Int)
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
        var accents: [String: (RGB, RGB?)] = [:]
        var stopped = false
        /// Номер запуска: колбэки старого процесса сверяют его и не трогают новый
        var generation = 0
        /// Первая строка нового процесса ещё не пришла
        var awaitingFirstLine = true
    }

    public init(paths: AdapterPaths) {
        self.paths = paths
        (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
    }

    public func start() {
        state.withLockUnchecked { $0.stopped = false }
        launch()
    }

    /// Гасит адаптер и ждёт его выхода до 0.5 с. Если perl не завершился по SIGTERM — SIGKILL.
    /// Зовётся из applicationWillTerminate
    public func stop() {
        let process = state.withLockUnchecked { s -> Process? in
            s.stopped = true
            return s.process
        }
        guard let process, process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(0.5)
        while process.isRunning, Date() < deadline { usleep(10_000) }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }

    public func send(_ command: MediaCommand) {
        run(["send", String(command.rawValue)])
    }

    public func setShuffle(_ mode: Int) {
        run(["shuffle", String(mode)])
    }

    public func setRepeat(_ mode: Int) {
        run(["repeat", String(mode)])
    }

    /// Разовая команда адаптера: отдельный perl, поток stream не трогаем
    private func run(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [paths.script.path, paths.framework.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // ненулевой статус — например, адаптер не принял режим shuffle/repeat: без этого лога было бы не отличить
        // от «команда просто не сработала» (вживую проверить в Task 17)
        process.terminationHandler = { [log, arguments] finished in
            guard finished.terminationStatus != 0 else { return }
            log.error("\(arguments.joined(separator: " "), privacy: .public) exited with status \(finished.terminationStatus)")
        }
        do {
            try process.run()
        } catch {
            log.error("\(arguments.joined(separator: " "), privacy: .public) failed: \(error.localizedDescription)")
        }
    }

    /// afterGeneration: перезапуск по backoff. Если за время ожидания был stop() или новый start(), не запускаемся
    private func launch(afterGeneration expected: Int? = nil) {
        let process = Process()
        let generation: Int? = state.withLockUnchecked { s in
            guard !s.stopped, expected == nil || s.generation == expected else { return nil }
            s.generation += 1
            s.process = process
            // хвост недописанной строки от умершего процесса не должен приклеиться к первой строке нового
            s.buffer = LineBuffer()
            s.awaitingFirstLine = true
            return s.generation
        }
        guard let generation else { return }
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
            self.receive(chunk, generation: generation)
        }
        process.terminationHandler = { [weak self] finished in
            self?.processEnded(generation: generation, status: finished.terminationStatus)
        }
        do {
            try process.run()
            log.info("adapter started")
            // stop() мог отработать между s.process = process и run(): isRunning тогда был false,
            // и process.terminate() не случился. Проверяем ещё раз после запуска
            let shouldStop = state.withLockUnchecked { s in s.stopped || s.generation != generation }
            if shouldStop { process.terminate() }
        } catch {
            log.error("adapter launch failed: \(error.localizedDescription)")
            processEnded(generation: generation, status: nil)
        }
    }

    private func receive(_ chunk: Data, generation: Int) {
        let changes = state.withLockUnchecked { s -> [NowPlayingChange] in
            // вывод старого процесса после перезапуска не нужен
            guard s.generation == generation else { return [] }
            return s.buffer.append(chunk).compactMap { line in
                let isFirstLine = s.awaitingFirstLine
                s.awaitingFirstLine = false
                guard let change = s.parser.consume(line, ignoringClear: isFirstLine) else { return nil }
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

    /// Цвета считаем один раз на трек: адаптер присылает обложку в каждой строке
    private func fillAccent(_ info: NowPlayingInfo) -> NowPlayingInfo {
        var info = info
        let key = info.trackKey
        if let cached = state.withLockUnchecked({ $0.accents[key] }) {
            info.accent = cached.0
            info.accentBottom = cached.1
        } else if let artwork = info.artwork, let both = ArtworkColor.accentAndBottom(of: artwork) {
            // один decode обложки вместо отдельных accent(of:) + gradient(of:)
            state.withLockUnchecked { $0.accents[key] = (both.accent, both.bottom) }
            info.accent = both.accent
            info.accentBottom = both.bottom
        }
        return info
    }

    /// Процесс адаптера завершился. Перезапуск — только если это текущий процесс и stop() не звали
    private func processEnded(generation: Int, status: Int32?) {
        let delay: Duration? = state.withLockUnchecked { s in
            guard s.generation == generation else { return nil }
            s.process = nil
            return s.stopped ? nil : s.backoff.next()
        }
        guard let delay else { return }
        if let status { log.error("adapter exited with status \(status)") }
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.launch(afterGeneration: generation)
        }
    }
}
