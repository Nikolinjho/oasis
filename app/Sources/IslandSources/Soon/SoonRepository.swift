import Foundation
import IslandCore

public enum SoonRepositoryError: Error, Equatable, Sendable, LocalizedError {
  case unsupportedSchema(Int)
  case invalidStore(String)

  public var errorDescription: String? {
    switch self {
    case .unsupportedSchema(let version): "Файл напоминаний имеет неподдерживаемую версию \(version)."
    case .invalidStore(let reason): "Не удалось прочитать напоминания: \(reason)"
    }
  }
}

public struct SoonRepositoryUpdate: Equatable, Sendable {
  public var reminders: [SoonReminder]
  public var newlyClaimed: [SoonReminder]

  public init(reminders: [SoonReminder], newlyClaimed: [SoonReminder]) {
    self.reminders = reminders
    self.newlyClaimed = newlyClaimed
  }
}

public actor SoonRepository {
  private struct Envelope: Codable {
    var schemaVersion: Int
    var reminders: [SoonReminder]
  }

  private enum LoadState {
    case unloaded
    case loaded
    case failed(SoonRepositoryError)
  }

  private let url: URL
  private var reminders: [SoonReminder] = []
  private var loadState: LoadState = .unloaded

  public init(url: URL) { self.url = url }

  @discardableResult
  public func load() throws -> [SoonReminder] {
    switch loadState {
    case .loaded: return reminders
    case .failed(let error): throw error
    case .unloaded: break
    }
    do {
      let data: Data
      do {
        data = try Data(contentsOf: url)
      } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
        loadState = .loaded
        return []
      }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .millisecondsSince1970
      let envelope = try decoder.decode(Envelope.self, from: data)
      guard envelope.schemaVersion == 1 else { throw SoonRepositoryError.unsupportedSchema(envelope.schemaVersion) }
      try Self.validate(envelope.reminders)
      reminders = envelope.reminders
      loadState = .loaded
      return reminders
    } catch {
      let failure = error as? SoonRepositoryError ?? .invalidStore(error.localizedDescription)
      // Повреждённый файл остаётся на диске, любые последующие записи заблокированы.
      loadState = .failed(failure)
      throw failure
    }
  }

  public func snapshot() throws -> [SoonReminder] { try load() }

  @discardableResult
  public func add(title: String, durationSeconds: Int, now: Date) throws -> SoonReminder {
    try ensureLoaded()
    let reminder = try SoonReminder(title: title, durationSeconds: durationSeconds, now: now)
    try commit(reminders + [reminder])
    return reminder
  }

  @discardableResult
  public func edit(
    id: UUID, revision: Int, title: String, durationSeconds: Int, now: Date
  ) throws -> SoonReminder? {
    try ensureLoaded()
    guard let index = matchingIndex(id: id, revision: revision) else { return nil }
    var updated = try rescheduled(reminders[index], seconds: durationSeconds, now: now)
    updated.title = try SoonReminder.normalizedTitle(title)
    updated.durationSeconds = durationSeconds
    try replace(updated, at: index)
    return updated
  }

  @discardableResult
  public func complete(id: UUID, revision: Int) throws -> SoonReminder? {
    try ensureLoaded()
    guard let index = matchingIndex(id: id, revision: revision), reminders[index].state != .completed else { return nil }
    var updated = reminders[index]
    updated.state = .completed
    try replace(updated, at: index)
    return updated
  }

  @discardableResult
  public func delete(id: UUID, revision: Int) throws -> SoonReminder? {
    try ensureLoaded()
    guard let index = matchingIndex(id: id, revision: revision) else { return nil }
    var candidate = reminders
    let deleted = candidate.remove(at: index)
    try commit(candidate)
    return deleted
  }

  @discardableResult
  public func snooze(id: UUID, revision: Int, seconds: Int, now: Date) throws -> SoonReminder? {
    try ensureLoaded()
    guard let index = matchingIndex(id: id, revision: revision), reminders[index].state != .completed else { return nil }
    let updated = try rescheduled(reminders[index], seconds: seconds, now: now)
    try replace(updated, at: index)
    return updated
  }

  @discardableResult
  public func repeatReminder(id: UUID, revision: Int, now: Date) throws -> SoonReminder? {
    try ensureLoaded()
    guard let index = matchingIndex(id: id, revision: revision) else { return nil }
    let updated = try rescheduled(reminders[index], seconds: reminders[index].durationSeconds, now: now)
    try replace(updated, at: index)
    return updated
  }

  @discardableResult
  public func clearCompleted() throws -> [SoonReminder] {
    try ensureLoaded()
    let candidate = reminders.filter { $0.state != .completed }
    if candidate != reminders { try commit(candidate) }
    return reminders
  }

  public func markDueAndClaimIsland(now: Date, claimIsland: Bool) throws -> SoonRepositoryUpdate {
    try ensureLoaded()
    guard now.timeIntervalSince1970.isFinite else { throw SoonReminderError.invalidDate }
    var candidate = reminders
    var claimed: [SoonReminder] = []
    for index in candidate.indices {
      if candidate[index].state == .scheduled, candidate[index].dueAt <= now {
        candidate[index].state = .due
      }
      if claimIsland, candidate[index].state == .due,
        candidate[index].islandClaimedRevision != candidate[index].revision
      {
        candidate[index].islandClaimedRevision = candidate[index].revision
        claimed.append(candidate[index])
      }
    }
    // Сначала фиксируем выдачу, затем возвращаем записи для показа островом.
    if candidate != reminders { try commit(candidate) }
    return SoonRepositoryUpdate(reminders: reminders, newlyClaimed: SoonSchedule.sorted(claimed, now: now))
  }

  private func ensureLoaded() throws { _ = try load() }

  private func matchingIndex(id: UUID, revision: Int) -> Int? {
    reminders.firstIndex { $0.id == id && $0.revision == revision }
  }

  private func rescheduled(_ reminder: SoonReminder, seconds: Int, now: Date) throws -> SoonReminder {
    var updated = reminder
    let next = updated.revision.addingReportingOverflow(1)
    guard !next.overflow else { throw SoonReminderError.revisionOverflow }
    updated.dueAt = try SoonReminder.deadline(now: now, durationSeconds: seconds)
    updated.revision = next.partialValue
    updated.state = .scheduled
    updated.islandClaimedRevision = nil
    return updated
  }

  private func replace(_ reminder: SoonReminder, at index: Int) throws {
    var candidate = reminders
    candidate[index] = reminder
    try commit(candidate)
  }

  private func commit(_ candidate: [SoonReminder]) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(Envelope(schemaVersion: 1, reminders: candidate))
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
    reminders = candidate
  }

  private static func validate(_ reminders: [SoonReminder]) throws {
    guard Set(reminders.map(\.id)).count == reminders.count else {
      throw SoonRepositoryError.invalidStore("повторяются идентификаторы")
    }
    for reminder in reminders {
      guard try SoonReminder.normalizedTitle(reminder.title) == reminder.title,
        (10...86_400).contains(reminder.durationSeconds), reminder.revision > 0,
        reminder.createdAt.timeIntervalSince1970.isFinite, reminder.dueAt.timeIntervalSince1970.isFinite,
        reminder.islandClaimedRevision.map({ $0 > 0 && $0 <= reminder.revision }) ?? true
      else { throw SoonRepositoryError.invalidStore("неверные данные напоминания") }
    }
  }
}
