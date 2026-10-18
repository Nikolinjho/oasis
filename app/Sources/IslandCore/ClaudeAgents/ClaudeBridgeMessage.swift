import Foundation

public struct ClaudeProcessOwner: Codable, Equatable, Sendable {
  public let pid: Int32
  public let startedAt: Date

  public init(pid: Int32, startedAt: Date) {
    self.pid = pid
    self.startedAt = startedAt
  }
}

public struct ClaudeBridgeEvent: Codable, Equatable, Sendable {
  public let eventID: UUID
  public let agent: ClaudeAgentID
  public let eventName: String
  public let observedAt: Date
  public let originalInput: Data
  public let owner: ClaudeProcessOwner?

  public init(
    eventID: UUID = UUID(), agent: ClaudeAgentID, eventName: String,
    observedAt: Date = Date(), originalInput: Data, owner: ClaudeProcessOwner? = nil
  ) {
    self.eventID = eventID
    self.agent = agent
    self.eventName = eventName
    self.observedAt = observedAt
    self.originalInput = originalInput
    self.owner = owner
  }
}

public enum ClaudeBridgeMessage: Codable, Equatable, Sendable {
  case hello(version: Int, launchID: UUID)
  case event(ClaudeBridgeEvent)
  case request(ClaudeRequest)
  case response(requestID: ClaudeRequestID, responseID: UUID, answer: ClaudeAnswer)
  case received(requestID: ClaudeRequestID, responseID: UUID)
  case cancelled(requestID: ClaudeRequestID, reason: String)
  case heartbeat(requestID: ClaudeRequestID)
  case error(code: String)
}
