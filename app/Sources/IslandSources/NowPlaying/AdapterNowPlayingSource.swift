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
  func seek(to position: TimeInterval)
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
    var accents = AccentCache()
    var stopped = false
    /// Номер запуска: колбэки старого процесса сверяют его и не трогают новый
    var generation = 0
    /// Первая строка нового процесса ещё не пришла
    var awaitingFirstLine = true
    /// Слежение за треком, оставшимся от предыдущего запуска (Task 13)
    var staleCheck = StaleTrackCheck()
  }

  public init(paths: AdapterPaths) {
    self.paths = paths
    (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
  }

  public func start() {
    state.withLockUnchecked { $0.stopped = false }
    launch()
  }

  /// Отмечает остановку сразу, ожидание завершения процесса выполняется вне главного потока
  public func stop() {
    let process = state.withLockUnchecked { s -> Process? in
      s.stopped = true
      return s.process
    }
    guard let process, process.isRunning else { return }
    process.terminate()
    Task.detached {
      let deadline = Date().addingTimeInterval(0.5)
      while process.isRunning, Date() < deadline { usleep(10_000) }
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
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

  /// seek адаптера принимает микросекунды
  public func seek(to position: TimeInterval) {
    run(Self.seekArguments(position))
  }

  /// Аргументы команды seek: секунды в микросекунды, отрицательная позиция зажата в 0
  nonisolated static func seekArguments(_ position: TimeInterval) -> [String] {
    ["seek", String(Int((max(position, 0) * 1_000_000).rounded()))]
  }

  /// Сколько ждать трек от перезапущенного адаптера. Замера нет, оценка: у живого адаптера строка
  /// с треком приходит сразу за пустой первой
  static let staleTimeout: Duration = .seconds(3)

  /// Первая строка перезапуска ничего не дала — она пустая или её не удалось разобрать, в обоих случаях
  /// change nil, — а трек был: запустить проверку старого трека.
  /// Первый запуск (generation 1) не в счёт — там трека ещё нет
  static func startsStaleCheck(isFirstLine: Bool, generation: Int, change: NowPlayingChange?, hasTrack: Bool) -> Bool {
    isFirstLine && generation > 1 && change == nil && hasTrack
  }

  /// Слежение за треком, оставшимся от предыдущего запуска: построчно копится в receive(),
  /// по таймауту проверяется в dropStaleTrack(). Вынесено в отдельный тип, чтобы решения проверялись
  /// юнит-тестами без реального Process и Task.sleep
  struct StaleTrackCheck: Equatable {
    private(set) var awaiting = false

    /// Очередная строка от адаптера. true — она вооружает проверку; строка с треком (change != nil) проверку снимает
    mutating func line(isFirst: Bool, generation: Int, change: NowPlayingChange?, hadTrack: Bool) -> Bool {
      if AdapterNowPlayingSource.startsStaleCheck(isFirstLine: isFirst, generation: generation, change: change, hasTrack: hadTrack) {
        awaiting = true
        return true
      }
      if change != nil { awaiting = false }
      return false
    }

    /// Сработал таймаут. true — трек пора забыть: проверка ещё активна, запуск тот же, adapter не
    /// остановлен и трек всё ещё висит
    mutating func timeout(generation: Int, currentGeneration: Int, stopped: Bool, hasTrack: Bool) -> Bool {
      guard awaiting, generation == currentGeneration, !stopped, hasTrack else { return false }
      awaiting = false
      return true
    }
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
      s.staleCheck = StaleTrackCheck()
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
    let (changes, staleCheck) = state.withLockUnchecked { s -> ([NowPlayingChange], Bool) in
      // вывод старого процесса после перезапуска не нужен
      guard s.generation == generation else { return ([], false) }
      var staleCheck = false
      let changes = s.buffer.append(chunk).compactMap { line -> NowPlayingChange? in
        let isFirstLine = s.awaitingFirstLine
        s.awaitingFirstLine = false
        let hadTrack = s.parser.current != nil
        let change = s.parser.consume(line, ignoringClear: isFirstLine)
        if s.staleCheck.line(isFirst: isFirstLine, generation: generation, change: change, hadTrack: hadTrack) {
          staleCheck = true
        }
        guard let change else { return nil }
        s.backoff.reset()
        return change
      }
      return (changes, staleCheck)
    }
    for change in changes {
      continuation.yield(withAccent(change))
    }
    if staleCheck {
      Task { [weak self] in await self?.dropStaleTrack(generation: generation) }
    }
  }

  /// Перезапущенный адаптер так и не прислал трек: музыки больше нет, старый трек не должен висеть
  private func dropStaleTrack(generation: Int) async {
    try? await Task.sleep(for: Self.staleTimeout)
    state.withLockUnchecked { s in
      guard
        s.staleCheck.timeout(generation: generation, currentGeneration: s.generation, stopped: s.stopped, hasTrack: s.parser.current != nil)
      else { return }
      s.parser = NowPlayingParser()
      log.info("adapter relaunched without a track: dropping the stale one")
      // yield здесь же, пока лок ещё держим: иначе receive() на своей очереди может между нашим
      // сбросом парсера и yield(.cleared) успеть распарсить свежий трек, сбросить staleCheck и
      // разослать .newTrack — и стрим получит .newTrack, а следом устаревший .cleared поверх него.
      // .cleared не трогает fillAccent (см. withAccent), так что повторного захвата лока тут нет
      continuation.yield(.cleared)
    }
  }

  private func withAccent(_ change: NowPlayingChange) -> NowPlayingChange {
    switch change {
    case .newTrack(let info): .newTrack(fillAccent(info))
    case .updated(let info): .updated(fillAccent(info))
    case .cleared: .cleared
    }
  }

  /// Цвета считаем один раз на трек: адаптер присылает обложку в каждой строке
  private func fillAccent(_ info: NowPlayingInfo) -> NowPlayingInfo {
    var info = info
    let key = info.trackKey
    let artwork = info.artwork
    switch state.withLockUnchecked({ $0.accents.lookup(key, artwork: artwork) }) {
    case .hit(let colors):
      info.accent = colors.accent
      info.accentBottom = colors.bottom
    case .knownFailure:
      break
    case .miss:
      guard let artwork else { break }
      // decode вне лока: один на обложку, сразу accent и низ для Gradient
      let colors = ArtworkColor.accentAndBottom(of: artwork).map { AccentCache.Colors(accent: $0.accent, bottom: $0.bottom) }
      state.withLockUnchecked { $0.accents.store(key, colors: colors, artwork: artwork) }
      info.accent = colors?.accent
      info.accentBottom = colors?.bottom
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
