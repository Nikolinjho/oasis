import Foundation

public struct CodexThreadSummary: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public var cwd: String
  public var name: String?
  public var status: Status

  public struct Status: Codable, Equatable, Sendable {
    public let type: String
    public let activeFlags: [String]?
  }
}

public enum CodexConnectionState: Equatable, Sendable {
  case stopped
  case connecting
  case connected
  case waiting(String)
}

public enum CodexClientEvent: Sendable {
  case connection(CodexConnectionState)
  case thread(CodexThreadSummary)
  case threadClosed(String)
  case question(CodexQuestionnaire)
  case resolved(CodexQuestionIdentity)
  case invalidated(UUID)
  case answerFailed(CodexQuestionIdentity)
}
