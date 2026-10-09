import IslandCore
import IslandSources

/// Смена источника снимает прежний трек и отвергает запоздавшие события его сессии
@MainActor
final class NowPlayingSourceSwitcher {
  private(set) var source: (any NowPlayingSource)?
  private var choice: MediaSourceChoice?
  private var task: Task<Void, Never>?
  private var statusTask: Task<Void, Never>?
  private var session = 0
  private let make: (MediaSourceChoice) -> (any NowPlayingSource)?
  private let onChange: (NowPlayingChange) -> Void
  private let onState: (NowPlayingSourceState) -> Void

  init(
    make: @escaping (MediaSourceChoice) -> (any NowPlayingSource)?,
    onChange: @escaping (NowPlayingChange) -> Void,
    onState: @escaping (NowPlayingSourceState) -> Void = { _ in }
  ) {
    self.make = make
    self.onChange = onChange
    self.onState = onState
  }

  func apply(_ choice: MediaSourceChoice) {
    guard choice != self.choice else { return }
    let hadSource = source != nil
    stop()
    if hadSource { onChange(.cleared) }
    self.choice = choice
    guard let source = make(choice) else {
      if choice == .yandexMusic { onState(.failed("Yandex Music bridge is missing from the application bundle.")) }
      return
    }
    self.source = source
    let current = session
    task = Task { [weak self] in
      for await change in source.changes {
        guard !Task.isCancelled, let self, session == current else { return }
        onChange(change)
      }
    }
    if let yandex = source as? any YandexSourceControlling {
      statusTask = Task { [weak self] in
        for await state in yandex.statuses {
          guard !Task.isCancelled, let self, session == current else { return }
          onState(state)
        }
      }
    }
    source.start()
  }

  func stop() {
    session += 1
    task?.cancel()
    statusTask?.cancel()
    task = nil
    statusTask = nil
    source?.stop()
    source = nil
    choice = nil
  }
}
