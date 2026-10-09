import Darwin
import Foundation
import IslandCore

/// Смотрит за каталогом: атомарная замена снимка меняет inode самого файла.
@MainActor
public final class ClaudeLimitsSource {
  public var onUpdate: (ClaudeLimits, [ClaudeLimits]) -> Void = { _, _ in }
  public var entries: [ClaudeLimits] { history.entries }

  private let directory: URL
  private var history = ClaudeHistory()
  private var last: ClaudeLimits?
  private var watcher: DispatchSourceFileSystemObject?
  private var generation = 0
  private let log = SourceLog.logger("claude")

  public init(directory: URL) {
    self.directory = directory
  }

  public func start() {
    guard watcher == nil else { return }
    generation += 1
    let activeGeneration = generation
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      log.error("Не удалось открыть каталог лимитов Claude Code")
      return
    }
    let historyURL = ClaudeFiles.history(in: directory)
    history = ClaudeHistory.load(from: historyURL, trimming: false)
    let loadedCount = history.entries.count
    history.trim(now: Date())
    if loadedCount != history.entries.count {
      do {
        try history.write(to: historyURL)
      } catch {
        log.error("Не удалось сократить историю лимитов Claude Code")
      }
    }
    last = nil
    let fd = open(directory.path, O_EVTONLY)
    guard fd >= 0 else {
      log.error("Не удалось наблюдать каталог лимитов Claude Code")
      return
    }
    let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
    source.setEventHandler { [weak self] in
      Task { @MainActor [weak self] in
        guard let self, self.generation == activeGeneration, self.watcher != nil else { return }
        self.reload()
      }
    }
    source.setCancelHandler { close(fd) }
    watcher = source
    source.resume()
    reload()
  }

  public func stop() {
    generation += 1
    watcher?.cancel()
    watcher = nil
    last = nil
  }

  private func reload() {
    guard let data = try? Data(contentsOf: ClaudeFiles.limits(in: directory)),
      let limits = ClaudeLimits.parse(data), !limits.isEmpty,
      limits.capturedAt <= Date().addingTimeInterval(60), limits != last
    else { return }
    let baseline = max(last?.capturedAt ?? .distantPast, history.entries.last?.capturedAt ?? .distantPast)
    guard limits.capturedAt >= baseline else { return }
    last = limits
    if history.record(limits) {
      history.trim(now: Date())
      do {
        try history.write(to: ClaudeFiles.history(in: directory))
      } catch {
        log.error("Не удалось сохранить историю лимитов Claude Code")
      }
    }
    onUpdate(limits, history.entries)
  }
}
