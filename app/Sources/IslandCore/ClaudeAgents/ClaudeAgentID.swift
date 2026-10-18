import Foundation

public struct ClaudeAgentID: Codable, Hashable, Sendable {
  public let provider: String
  public let sessionID: String
  public let agentID: String?

  public init(provider: String = "claude-code", sessionID: String, agentID: String? = nil) {
    self.provider = provider
    self.sessionID = sessionID
    self.agentID = agentID
  }
}

public struct ClaudeRequestID: Codable, Hashable, Sendable {
  public let agent: ClaudeAgentID
  public let value: UUID
  public let revision: UInt64

  public init(agent: ClaudeAgentID, value: UUID = UUID(), revision: UInt64 = 1) {
    self.agent = agent
    self.value = value
    self.revision = revision
  }
}

public enum ClaudeBridgeLimits {
  public static let protocolVersion = 1
  public static let maximumInputBytes = 512 * 1024
  public static let maximumFrameBytes = 1024 * 1024
  public static let hookTimeoutSeconds = 600
  public static let requestLifetimeSeconds = 590
  public static let maximumConnections = 64
}
