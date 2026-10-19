import Foundation

public enum CodexRequestID: Codable, Hashable, Sendable {
  case string(String)
  case integer(Int64)

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer()
    if let integer = try? value.decode(Int64.self) { self = .integer(integer) } else { self = .string(try value.decode(String.self)) }
  }

  public func encode(to encoder: any Encoder) throws {
    var value = encoder.singleValueContainer()
    switch self {
    case .string(let text): try value.encode(text)
    case .integer(let integer): try value.encode(integer)
    }
  }
}

public struct CodexQuestion: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let header: String
  public let question: String
  public let isOther: Bool
  public let isSecret: Bool
  public let options: [Option]?

  public struct Option: Codable, Equatable, Sendable {
    public let label: String
    public let description: String
  }
}

public struct CodexQuestionIdentity: Hashable, Sendable {
  public let generation: UUID
  public let threadID: String
  public let requestID: CodexRequestID

  public init(generation: UUID, threadID: String, requestID: CodexRequestID) {
    self.generation = generation
    self.threadID = threadID
    self.requestID = requestID
  }
}

public struct CodexQuestionnaire: Equatable, Sendable, Identifiable {
  public let id: CodexQuestionIdentity
  public let turnID: String
  public let itemID: String
  public let questions: [CodexQuestion]
  public let isBlocking: Bool

  public init(
    id: CodexQuestionIdentity, turnID: String, itemID: String,
    questions: [CodexQuestion], isBlocking: Bool
  ) {
    self.id = id
    self.turnID = turnID
    self.itemID = itemID
    self.questions = questions
    self.isBlocking = isBlocking
  }
}
