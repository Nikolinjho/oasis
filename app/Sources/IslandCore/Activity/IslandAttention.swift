import Foundation

public struct IslandAttention: Identifiable, Equatable, Sendable {
  public enum Source: Equatable, Sendable {
    case alert(IslandAlert)
    case music
    case calendar(CalendarEvent)
  }

  public let id: UUID
  public var source: Source
  public var title: String
  public var detail: String
  public var observedAt: Date
  public var expiresAt: Date?
  public var peekEligibleUntil: Date?
  public var active: Bool
  public var unread: Bool

  public init(
    id: UUID = UUID(), source: Source, title: String, detail: String = "", observedAt: Date = Date(),
    active: Bool = true, unread: Bool = true, expiresAt: Date? = nil, peekEligibleUntil: Date? = nil
  ) {
    self.id = id
    self.source = source
    self.title = title
    self.detail = detail
    self.observedAt = observedAt
    self.expiresAt = expiresAt
    self.peekEligibleUntil = peekEligibleUntil
    self.active = active
    self.unread = unread
  }
}
