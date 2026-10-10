import AppKit
import IslandCore
import IslandSources
import Observation

private struct SoonIslandClaim {
  let reminder: SoonReminder
  let catchUp: Bool
  let native: Bool
}

@MainActor
@Observable
final class SoonModule {
  private(set) var reminders: [SoonReminder] = []
  private(set) var delivery = SoonDeliveryStatus()
  private(set) var error: String?
  private(set) var isRunning = false
  private(set) var selectedID: UUID?
  private(set) var showsCompleted = false
  @ObservationIgnored let notifications: SoonNotifications
  @ObservationIgnored private let settings: AppSettings
  @ObservationIgnored private let store: IslandStore
  @ObservationIgnored private var repository: SoonRepository
  @ObservationIgnored private let liveRepository: SoonRepository
  @ObservationIgnored private var timer: Task<Void, Never>?
  @ObservationIgnored private var operations: Task<Void, Never>?
  @ObservationIgnored private var generation = 0
  @ObservationIgnored private var debugMode = false
  @ObservationIgnored private var pendingIsland: [String: SoonIslandClaim] = [:]
  @ObservationIgnored var composer: SoonComposerController?
  @ObservationIgnored var onStart: () -> Void = {}
  @ObservationIgnored var onStop: () -> Void = {}

  init(store: IslandStore, settings: AppSettings, notifications: SoonNotifications, url: URL) {
    self.store = store
    self.settings = settings
    self.notifications = notifications
    let repository = SoonRepository(url: url)
    self.repository = repository
    liveRepository = repository
    notifications.onStatus = { [weak self] status in
      self?.delivery = status
      self?.publish()
    }
    store.onSoonAction = { [weak self] action in self?.perform(action) }
  }

  func start() {
    notifications.handleActions { [weak self] action in self?.receive(action) }
    applySettings()
  }

  func applySettings() {
    generation += 1
    timer?.cancel()
    timer = nil
    let starting = !isRunning
    isRunning = settings.soon.enabled
    if isRunning {
      onStart()
    } else {
      onStop()
      retractNotices()
      pendingIsland.removeAll()
      composer?.close(force: true)
    }
    if !settings.soon.showInIsland {
      retractNotices()
      pendingIsland.removeAll()
    }
    enqueue { module in await module.reconcile(catchUp: starting) }
  }

  /// Выход завершает только локальную работу. Запросы macOS продолжают жить.
  func stop() {
    generation += 1
    isRunning = false
    timer?.cancel()
    timer = nil
    onStop()
    composer?.close(force: true)
  }

  func systemTimeChanged(catchUp: Bool = true) {
    guard isRunning else { return }
    enqueue { module in await module.reconcile(catchUp: catchUp) }
  }

  func perform(_ action: SoonAction) {
    guard settings.soon.enabled else { return }
    switch action {
    case .create: composer?.show(.new)
    case .showList:
      selectedID = nil
      showsCompleted = false
      openIsland()
    case .showCompleted:
      selectedID = nil
      showsCompleted = true
      openIsland()
    case .open(let id, let revision):
      guard let reminder = matching(id, revision) else { return }
      selectedID = reminder.id
      showsCompleted = reminder.state == .completed
      openIsland()
    case .edit(let id, let revision), .customSnooze(let id, let revision), .repeatReminder(let id, let revision):
      guard let reminder = matching(id, revision) else { return }
      composer?.show(.existing(reminder, action: action))
    default:
      enqueue { module in await module.mutate(action) }
    }
  }

  func submit(title: String, duration: String, mode: SoonComposerMode) async throws {
    let seconds = try SoonDurationParser.parse(duration)
    let title = try SoonReminder.normalizedTitle(title)
    let submissionRepository = repository
    let submissionDebugMode = debugMode
    // Команда формы идёт через ту же очередь, что действия баннера и локального таймера.
    let previous = operations
    let operation = Task<Void, Error> { [weak self] in
      await previous?.value
      try Task.checkCancellation()
      guard let self, self.isRunning else { throw SoonModuleError.disabled }
      guard repository === submissionRepository else { throw SoonModuleError.stale }
      let now = Date()
      switch mode {
      case .new:
        _ = try await submissionRepository.add(title: title, durationSeconds: seconds, now: now)
      case .existing(let reminder, _):
        guard
          try await submissionRepository.edit(
            id: reminder.id, revision: reminder.revision, title: title, durationSeconds: seconds, now: now) != nil
        else { throw SoonModuleError.stale }
      }
      guard repository === submissionRepository, isRunning else { return }
      if settings.soon.systemNotifications, !submissionDebugMode {
        composer?.authorizationPending = true
        await notifications.requestAuthorization()
        composer?.authorizationPending = false
      }
      guard repository === submissionRepository, isRunning else { return }
      selectedID = nil
      showsCompleted = false
      await reconcile(catchUp: false)
    }
    operations = Task { _ = try? await operation.value }
    try await withTaskCancellationHandler {
      try await operation.value
    } onCancel: {
      operation.cancel()
    }
  }

  private func mutate(_ action: SoonAction) async {
    guard isRunning else { return }
    do {
      switch action {
      case .complete(let id, let revision): _ = try await repository.complete(id: id, revision: revision)
      case .delete(let id, let revision): _ = try await repository.delete(id: id, revision: revision)
      case .snooze(let id, let revision, let seconds):
        _ = try await repository.snooze(id: id, revision: revision, seconds: seconds, now: Date())
        selectedID = nil
      case .clearCompleted: _ = try await repository.clearCompleted()
      default: return
      }
      await reconcile(catchUp: false)
    } catch { present(error) }
  }

  private func reconcile(catchUp: Bool) async {
    let activeGeneration = generation
    do {
      if !isRunning {
        await notifications.cancelAll()
        guard activeGeneration == generation else { return }
        publish()
        return
      }
      let now = Date()
      let activeRepository = repository
      let nativeIDs = delivery.scheduledIDs
      let update = try await activeRepository.markDueAndClaimIsland(now: now, claimIsland: true)
      if activeRepository === repository, isRunning, settings.soon.showInIsland {
        for reminder in update.newlyClaimed {
          pendingIsland[reminder.occurrenceID] = SoonIslandClaim(
            reminder: reminder, catchUp: catchUp, native: nativeIDs.contains(reminder.occurrenceID))
        }
      }
      guard activeGeneration == generation, isRunning else { return }
      reminders = update.reminders
      error = nil
      if let selectedID, !reminders.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
      retractObsoleteNotices()
      if !debugMode {
        await notifications.synchronize(
          reminders, enabled: settings.soon.systemNotifications,
          sound: settings.soon.playSound && settings.playSounds)
      }
      guard activeGeneration == generation, isRunning else { return }
      publish()
      if settings.soon.showInIsland {
        let valid = Set(reminders.filter { $0.state == .due }.map(\.occurrenceID))
        let pending = pendingIsland.values.filter { valid.contains($0.reminder.occurrenceID) }
        pendingIsland.removeAll()
        let quiet = pending.filter(\.catchUp).map(\.reminder)
        let normal = pending.filter { !$0.catchUp }
        show(SoonSchedule.sorted(quiet, now: Date()), catchUp: true, nativeIDs: [])
        show(
          SoonSchedule.sorted(normal.map(\.reminder), now: Date()), catchUp: false,
          nativeIDs: Set(normal.filter(\.native).map { $0.reminder.occurrenceID }))
      }
      scheduleTimer()
    } catch { present(error) }
  }

  private func show(_ due: [SoonReminder], catchUp: Bool, nativeIDs: Set<String>) {
    guard !due.isEmpty else { return }
    if catchUp {
      if let summary = SoonNotice.summary(due) { store.send(.alertArrived(.soon(summary))) }
      return
    }
    for reminder in due {
      let nativeSound = settings.soon.systemNotifications && delivery.eligibleNative && nativeIDs.contains(reminder.occurrenceID)
      let sound: SoonSoundChannel =
        settings.soon.playSound && settings.playSounds
        ? (nativeSound ? .native : .island) : .none
      store.send(.alertArrived(.soon(SoonNotice(reminder: reminder, soundChannel: sound))))
    }
  }

  private func scheduleTimer() {
    timer?.cancel()
    timer = nil
    let now = Date()
    guard isRunning, let next = reminders.filter({ $0.state == .scheduled }).min(by: { $0.dueAt < $1.dueAt }) else { return }
    let activeGeneration = generation
    timer = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(0, next.dueAt.timeIntervalSince(now))))
      guard !Task.isCancelled, let self, self.generation == activeGeneration, self.isRunning else { return }
      self.enqueue { module in await module.reconcile(catchUp: false) }
    }
  }

  private func enqueue(_ operation: @escaping @MainActor (SoonModule) async -> Void) {
    let previous = operations
    let targetRepository = repository
    operations = Task { [weak self] in
      await previous?.value
      guard let self, self.repository === targetRepository else { return }
      await operation(self)
    }
  }

  private func retractNotices() {
    for reminder in reminders { store.send(.alertRetracted(.soon(occurrenceID: reminder.occurrenceID))) }
  }

  private func retractObsoleteNotices() {
    let active = Set(reminders.filter { $0.state == .due }.map(\.occurrenceID))
    var kinds = store.model.alertQueue.map(\.kind)
    if case .alert(let alert) = store.model.surface { kinds.append(alert.kind) }
    if case .alert(let alert) = store.model.pending { kinds.append(alert.kind) }
    for kind in kinds {
      if case .soon(let id) = kind, !active.contains(id) { store.send(.alertRetracted(kind)) }
    }
  }

  func useDebugRepository(_ repository: SoonRepository?, catchUp: Bool = true) {
    generation += 1
    timer?.cancel()
    composer?.close(force: true)
    retractNotices()
    self.repository = repository ?? liveRepository
    debugMode = repository != nil
    pendingIsland.removeAll()
    selectedID = nil
    showsCompleted = false
    enqueue { module in await module.reconcile(catchUp: catchUp) }
  }
}

extension SoonModule {
  private func receive(_ action: SoonNotificationAction) {
    if debugMode { useDebugRepository(nil) }
    let targetRepository = repository
    enqueue { module in
      await module.reconcile(catchUp: true)
      guard module.repository === targetRepository else { return }
      switch action.kind {
      case .open: module.perform(.open(id: action.id, revision: action.revision))
      case .complete: await module.mutate(.complete(id: action.id, revision: action.revision))
      case .snooze: await module.mutate(.snooze(id: action.id, revision: action.revision, seconds: 300))
      }
    }
  }

  private func publish() {
    store.applySoon(
      isRunning
        ? SoonPanel(
          reminders: reminders, now: Date(), selectedID: selectedID, showsCompleted: showsCompleted, deliveryStatus: delivery) : nil)
  }

  private func openIsland() {
    publish()
    store.send(.expandedViewRequested(.soon))
  }

  private func matching(_ id: UUID, _ revision: Int) -> SoonReminder? {
    reminders.first { $0.id == id && $0.revision == revision }
  }

  private func present(_ failure: Error) {
    error = failure.localizedDescription
    delivery.error = error
    publish()
  }

}

enum SoonModuleError: Error, LocalizedError {
  case disabled, stale
  var errorDescription: String? {
    switch self {
    case .disabled: "Soon выключен. Включи его в настройках."
    case .stale: "Напоминание уже изменилось. Открой его снова."
    }
  }
}
