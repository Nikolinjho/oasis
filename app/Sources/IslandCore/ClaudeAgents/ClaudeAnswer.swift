import Foundation

public enum ClaudeAnswer: Codable, Equatable, Sendable {
  case questions([ClaudeQuestionAnswer])
  case allowOnce
  case deny(message: String?)
}

public struct ClaudeQuestionAnswer: Codable, Equatable, Sendable {
  public let questionIndex: Int
  public let selection: Selection

  public enum Selection: Codable, Equatable, Sendable {
    case options([Int])
    case text(String)
  }

  public init(questionIndex: Int, selection: Selection) {
    self.questionIndex = questionIndex
    self.selection = selection
  }
}
