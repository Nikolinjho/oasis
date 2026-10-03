import IslandCore
import IslandSources

/// Источник Now Playing по настройке Source: смена выбора применяется на лету, без перезапуска приложения.
/// Старый источник гасится, его трек снимается (.cleared), события из его потока больше не доходят
@MainActor
final class NowPlayingSourceSwitcher {
  private(set) var source: (any NowPlayingSource)?
  private var choice: MediaSourceChoice?
  private var task: Task<Void, Never>?
  /// nil — источник не создать (нет адаптера в бандле): выбор всё равно запоминается, ретраев нет
  private let make: (MediaSourceChoice) -> (any NowPlayingSource)?
  private let onChange: (NowPlayingChange) -> Void

  init(make: @escaping (MediaSourceChoice) -> (any NowPlayingSource)?, onChange: @escaping (NowPlayingChange) -> Void) {
    self.make = make
    self.onChange = onChange
  }

  /// Зовётся при запуске и на каждое изменение настроек: тот же выбор источник не трогает
  func apply(_ choice: MediaSourceChoice) {
    guard choice != self.choice else { return }
    let hadSource = source != nil
    stop()
    // трек прежнего источника не должен остаться на острове, пока новый молчит
    if hadSource { onChange(.cleared) }
    self.choice = choice
    guard let source = make(choice) else {
      self.source = nil
      return
    }
    let onChange = onChange
    task = Task {
      for await change in source.changes {
        // буфер потока мог отдать событие уже после смены источника
        guard !Task.isCancelled else { return }
        onChange(change)
      }
    }
    source.start()
    self.source = source
  }

  func stop() {
    task?.cancel()
    task = nil
    source?.stop()
  }
}
