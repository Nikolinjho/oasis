import Foundation

public struct ClaudeQuestionID: Codable, Hashable, Sendable {
  public let agent: ClaudeAgentID
  public let toolUseID: String

  public init(agent: ClaudeAgentID, toolUseID: String) {
    self.agent = agent
    self.toolUseID = toolUseID
  }
}

public struct ClaudeQuestionCompletion: Codable, Equatable, Sendable {
  public enum Outcome: String, Codable, Sendable { case terminal, oasis, cancelled }

  public let question: ClaudeQuestionID
  public let outcome: Outcome
  public let responseID: UUID?

  public init(question: ClaudeQuestionID, outcome: Outcome, responseID: UUID? = nil) {
    self.question = question
    self.outcome = outcome
    self.responseID = responseID
  }
}
