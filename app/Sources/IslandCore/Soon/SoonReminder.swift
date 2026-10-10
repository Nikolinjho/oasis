import Foundation

public enum SoonReminderState: String, Codable, Equatable, Sendable {
  case scheduled, due, completed
}

public enum SoonReminderError: Error, Equatable, Sendable, LocalizedError {
  case invalidTitle
  case invalidDate
  case revisionOverflow

  public var errorDescription: String? {
    switch self {
    case .invalidTitle: "Название должно содержать от 1 до 150 символов."
    case .invalidDate: "Не удалось определить время напоминания."
    case .revisionOverflow: "Не удалось обновить напоминание."
    }
  }
}

public struct SoonReminder: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var title: String
  public var createdAt: Date
  public var dueAt: Date
  public var durationSeconds: Int
  public var revision: Int
  public var state: SoonReminderState
  public var islandClaimedRevision: Int?

  public var occurrenceID: String { "soon.\(id.uuidString).\(revision)" }

  public init(
    id: UUID, title: String, createdAt: Date, dueAt: Date, durationSeconds: Int,
    revision: Int = 1, state: SoonReminderState = .scheduled, islandClaimedRevision: Int? = nil
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.dueAt = dueAt
    self.durationSeconds = durationSeconds
    self.revision = revision
    self.state = state
    self.islandClaimedRevision = islandClaimedRevision
  }

  public init(title: String, durationSeconds: Int, now: Date, id: UUID = UUID()) throws {
    self.init(
      id: id, title: try Self.normalizedTitle(title), createdAt: now,
      dueAt: try Self.deadline(now: now, durationSeconds: durationSeconds), durationSeconds: durationSeconds)
  }

  public static func normalizedTitle(_ title: String) throws -> String {
    let normalized = title.components(separatedBy: .newlines).joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...150).contains(normalized.count) else { throw SoonReminderError.invalidTitle }
    return normalized
  }

  public static func deadline(now: Date, durationSeconds: Int) throws -> Date {
    guard (10...86_400).contains(durationSeconds) else { throw SoonDurationError.outOfRange }
    let seconds = now.timeIntervalSince1970 + Double(durationSeconds)
    guard seconds.isFinite else { throw SoonReminderError.invalidDate }
    return Date(timeIntervalSince1970: seconds.rounded(.up))
  }
}
