import Foundation
import IslandCore
import IslandSources

/// Источник лимитов, прогноз и уведомления. Отладочные данные остаются только в памяти.
@MainActor
final class ClaudeModule {
  var clock: () -> Date = Date.init
  var calendar: Calendar = .current

  private let store: IslandStore
  private let settings: AppSettings
  private let source: ClaudeLimitsSource
  private var tracker = ClaudeThresholdTracker()
  private var latest: ClaudeLimits?
  private var history: [ClaudeLimits] = []
  private var ticker: Task<Void, Never>?
  private var resetTimer: Task<Void, Never>?
  private var debugPinned = false
  private(set) var isRunning = false

  init(store: IslandStore, settings: AppSettings, directory: URL) {
    self.store = store
    self.settings = settings
    source = ClaudeLimitsSource(directory: directory)
    source.onUpdate = { [weak self] limits, history in
      guard let self, self.isRunning, !self.debugPinned else { return }
      self.receive(limits, history: history)
    }
  }

  func applySettings() {
    guard settings.claude.enabled else { return stop() }
    if !settings.claude.sessionWarning { store.send(.alertRetracted(.claude)) }
    if !isRunning {
      isRunning = true
      source.start()
      startTicker()
    }
    // Настройки порогов сразу задают новую исходную точку: следующий расход уже сравнивается с ней.
    refresh()
    scheduleReset()
  }

  func stop() {
    isRunning = false
    source.stop()
    ticker?.cancel()
    resetTimer?.cancel()
    ticker = nil
    resetTimer = nil
    latest = nil
    history = []
    tracker = ClaudeThresholdTracker()
    debugPinned = false
    store.send(.alertRetracted(.claude))
    publish()
  }

  func receive(_ limits: ClaudeLimits, history: [ClaudeLimits]) {
    guard settings.claude.enabled else { return }
    latest = limits
    self.history = history
    refresh()
    scheduleReset()
  }

  func inject(_ limits: ClaudeLimits) {
    debugPinned = true
    receive(limits, history: history + [limits])
  }

  func inject(history: [ClaudeLimits]) {
    clear()
    guard let last = history.last else { return }
    receive(last, history: history)
  }

  func clear() {
    debugPinned = true
    tracker = ClaudeThresholdTracker()
    resetTimer?.cancel()
    resetTimer = nil
    latest = nil
    history = []
    store.send(.alertRetracted(.claude))
    publish()
  }

  var current: ClaudeLimits? { latest }

  /// Явный возврат из Debug: новый живой снимок снова задаёт молчаливую исходную точку.
  func resumeLive() {
    guard isRunning, settings.claude.enabled else { return }
    debugPinned = false
    reloadSource()
  }

  /// Пробуждение и смена часов сохраняют отладочный снимок до явного claude.live.
  func systemTimeChanged() {
    guard isRunning, settings.claude.enabled else { return }
    calendar = .current
    if debugPinned {
      refresh()
      scheduleReset()
      startTicker()
    } else {
      reloadSource()
    }
  }

  private func reloadSource() {
    tracker = ClaudeThresholdTracker()
    latest = nil
    history = []
    resetTimer?.cancel()
    resetTimer = nil
    store.send(.alertRetracted(.claude))
    source.stop()
    source.start()
    refresh()
    scheduleReset()
    startTicker()
  }

  private func refresh() {
    guard let latest else { return publish() }
    let now = clock()
    let fresh = now.timeIntervalSince(latest.capturedAt) <= ClaudePanel.staleAfter
    let runsOut = fresh ? LimitForecast.sessionRunsOutAt(history: history, now: now) : nil
    if let notice = tracker.update(latest, runsOutAt: runsOut, now: now, config: settings.claude.alertConfig),
      fresh || notice.reason == .reset, notice.urgent || !store.model.isFullscreen
    {
      store.send(.alertArrived(.claude(notice)))
    }
    publish()
  }

  private func publish() {
    guard settings.claude.enabled, settings.claude.expandedView, let latest, !latest.isEmpty else {
      store.applyClaude(nil)
      return
    }
    let now = clock()
    let horizon = settings.claude.horizon
    store.applyClaude(
      ClaudePanel(
        limits: latest, day: LimitForecast.day(history: history, now: now, horizon: horizon, calendar: calendar),
        now: now, horizon: horizon, calendar: calendar))
  }

  private func startTicker() {
    ticker?.cancel()
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled, let self, self.isRunning else { return }
        self.refresh()
      }
    }
  }

  private func scheduleReset() {
    resetTimer?.cancel()
    resetTimer = nil
    let now = clock()
    let dates = [latest?.fiveHour?.resetsAt, latest?.sevenDay?.resetsAt].compactMap { $0 }.filter { $0 > now }
    guard let resetsAt = dates.min() else { return }
    resetTimer = Task { [weak self] in
      try? await Task.sleep(for: .seconds(resetsAt.timeIntervalSince(now) + 1))
      guard !Task.isCancelled, let self, self.isRunning else { return }
      self.refresh()
      self.scheduleReset()
    }
  }
}
