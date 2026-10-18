import Foundation

public enum ClaudeRequestPhase: String, Codable, Sendable {
  case waiting, sending, accepted, continued, declined
  case expired, cancelled, disconnected
}

public struct ClaudeRequest: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable { case questions, permission }

  public let id: ClaudeRequestID
  public let kind: Kind
  public let toolName: String
  public let toolUseID: String?
  public let originalInput: Data
  public let questions: [ClaudeQuestion]
  public let createdAt: Date
  public let deadline: Date
  public var phase: ClaudeRequestPhase

  public init(
    id: ClaudeRequestID, kind: Kind, toolName: String, toolUseID: String? = nil,
    originalInput: Data, questions: [ClaudeQuestion] = [], createdAt: Date = Date(),
    deadline: Date? = nil, phase: ClaudeRequestPhase = .waiting
  ) {
    self.id = id
    self.kind = kind
    self.toolName = toolName
    self.toolUseID = toolUseID
    self.originalInput = originalInput
    self.questions = questions
    self.createdAt = createdAt
    self.deadline = deadline ?? createdAt.addingTimeInterval(Double(ClaudeBridgeLimits.requestLifetimeSeconds))
    self.phase = phase
  }
}
