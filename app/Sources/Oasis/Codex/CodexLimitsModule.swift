import Combine
import Foundation
import IslandCore
import IslandSources

@MainActor
final class CodexLimitsModule: ObservableObject {
  let settings: LimitsSettings
  @Published private(set) var panel = CodexLimitsPanel()
  private let source: CodexLimitsSource
  private let store: IslandStore
  private var monitor = CodexLimitsMonitor()
  private var started = false
  private var running = false
  private var lastNotice: CodexNotice?
  private var ticker: Task<Void, Never>?

  init(store: IslandStore, defaults: UserDefaults = .standard, source: CodexLimitsSource = CodexLimitsSource()) {
    self.store = store
    self.source = source
    settings = LimitsSettings(defaults: defaults, namespace: "codex.limits")
    settings.onChange = { [weak self] in self?.applySettings() }
  }

  func start() {
    started = true
    applySettings()
  }

  func applySettings() {
    guard settings.enabled else { return stopSource() }
    if let lastNotice,
      lastNotice.details.reason == .reset ? !settings.resetNotice : !settings.sessionWarning
    {
      store.send(.alertRetracted(.codex))
      self.lastNotice = nil
    }
    if started, !running {
      running = true
      source.start { [weak self] update in
        guard let self, self.running, self.settings.enabled else { return }
        self.receive(update)
      }
      startTicker()
    }
    if let limits = panel.limits {
      _ = monitor.receive(limits, now: Date(), config: settings.alertConfig)
    }
    publish(now: Date())
  }

  func stop() {
    started = false
    stopSource()
  }

  func refresh() {
    guard running else { return }
    source.refresh()
  }

  func receive(_ update: CodexLimitsSource.Update, now: Date = Date()) {
    guard settings.enabled else { return }
    switch update {
    case .limits(let limits):
      let notice = monitor.receive(limits, now: now, config: settings.alertConfig)
      panel = monitor.panel(now: now, horizon: settings.horizon)
      if let notice, notice.details.urgent || !store.model.isFullscreen {
        lastNotice = notice
        store.send(.alertArrived(.codex(notice)))
      }
    case .unavailable(let message):
      panel.status = message
      panel.now = now
      store.send(.alertRetracted(.codex))
    }
    publish(now: now)
  }

  private func publish(now: Date) {
    let status = panel.status
    panel = monitor.panel(now: now, status: status, horizon: settings.horizon)
    // При ошибке подключения сохранённые лимиты остаются видны, прогноз недоступен.
    if status != nil { panel.forecastText = nil }
    store.applyCodex(settings.enabled && settings.expandedView ? panel : nil)
  }

  private func stopSource() {
    running = false
    source.stop()
    ticker?.cancel()
    ticker = nil
    monitor = CodexLimitsMonitor()
    lastNotice = nil
    panel = CodexLimitsPanel()
    store.send(.alertRetracted(.codex))
    store.applyCodex(nil)
  }

  private func startTicker() {
    ticker?.cancel()
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled, let self, self.running else { return }
        self.publish(now: Date())
      }
    }
  }
}
