import Foundation

public enum ClaudeAgentState: String, Equatable, Sendable {
  case working, waiting, finished, error, stale, closed

  public var title: String {
    switch self {
    case .working: "Работает"
    case .waiting: "Ждёт ответа"
    case .finished: "Ход завершён"
    case .error: "Ошибка инструмента"
    case .stale: "Нет свежих событий"
    case .closed: "Сессия закрыта"
    }
  }
}

public struct ClaudeAgentSnapshot: Identifiable, Equatable, Sendable {
  public let id: ClaudeAgentID
  public var project: String
  public var directory: String
  public var branch: String?
  public var title: String?
  public var state: ClaudeAgentState
  public var observedAt: Date
  public var detail: String
  public var parent: ClaudeAgentID?

  public init(
    id: ClaudeAgentID, project: String, directory: String, branch: String? = nil,
    title: String? = nil, state: ClaudeAgentState = .working, observedAt: Date = Date(),
    detail: String = "", parent: ClaudeAgentID? = nil
  ) {
    self.id = id
    self.project = project
    self.directory = directory
    self.branch = branch
    self.title = title
    self.state = state
    self.observedAt = observedAt
    self.detail = detail
    self.parent = parent
  }
}

public struct ClaudeTextPosition: Equatable, Sendable {
  public var location: Int
  public var length: Int
  public var scrollY: Double

  public init(location: Int = 0, length: Int = 0, scrollY: Double = 0) {
    self.location = location
    self.length = length
    self.scrollY = scrollY
  }
}

public struct ClaudeReplyDraft: Equatable, Sendable {
  public var texts: [Int: String] = [:]
  public var options: [Int: Set<Int>] = [:]
  public var questionIndex = 0
  public var positions: [Int: ClaudeTextPosition] = [:]

  public init() {}

  public func answer(for request: ClaudeRequest) -> ClaudeAnswer? {
    guard request.kind == .questions, !request.questions.isEmpty else { return nil }
    var answers: [ClaudeQuestionAnswer] = []
    for (index, question) in request.questions.enumerated() {
      let text = texts[index] ?? ""
      if question.allowsOther || question.options.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        answers.append(.init(questionIndex: index, selection: .text(text)))
      } else {
        let selected = (options[index] ?? []).sorted()
        guard !selected.isEmpty, question.multiSelect || selected.count == 1,
          selected.allSatisfy({ question.options.indices.contains($0) })
        else { return nil }
        answers.append(.init(questionIndex: index, selection: .options(selected)))
      }
    }
    return .questions(answers)
  }
}

public enum AgentProvider: String, Equatable, Sendable {
  case claude = "claude-code"
  case codex

  public var title: String { self == .codex ? "Codex" : "Claude Code" }
  public var shortTitle: String { self == .codex ? "Codex" : "Claude" }
  public var view: ExpandedView { self == .codex ? .codexAgents : .agents }
}

public struct ClaudeAgentsPanel: Equatable, Sendable {
  public var provider: AgentProvider
  public var agents: [ClaudeAgentSnapshot] = []
  public var requests: [ClaudeRequest] = []
  public var selectedAgentID: ClaudeAgentID?
  public var selectedRequestID: ClaudeRequestID?
  public var drafts: [ClaudeRequestID: ClaudeReplyDraft] = [:]
  public var connected = false
  public var hasConnectionRecord = false
  public var hasForeignDecisionHooks = false
  public var error: String?
  public var compact = false
  public var attention: [IslandAttention] = []
  public var showsInbox = false
  public var waitingOnly = false

  public init(provider: AgentProvider = .claude) { self.provider = provider }
  public var selectedAgent: ClaudeAgentSnapshot? { agents.first { $0.id == selectedAgentID } }
  public var selectedRequest: ClaudeRequest? { requests.first { $0.id == selectedRequestID } }
  public var waiting: [ClaudeRequest] { requests.filter { $0.phase == .waiting || $0.phase == .sending } }
  public var waitingCount: Int { waiting.count }
  public var draft: ClaudeReplyDraft { selectedRequestID.flatMap { drafts[$0] } ?? .init() }
  public var width: CGFloat { compact ? 560 : 640 }
  public var height: CGFloat { compact ? 288 : 320 }
}

public enum ClaudeAgentsAction: Sendable {
  case openPanel
  case openRequest(ClaudeRequestID)
  case selectAgent(ClaudeAgentID)
  case selectRequest(ClaudeRequestID)
  case selectQuestion(ClaudeRequestID, Int)
  case toggleOption(ClaudeRequestID, question: Int, option: Int)
  case text(ClaudeRequestID, question: Int, value: String)
  case textPosition(ClaudeRequestID, question: Int, position: ClaudeTextPosition)
  case send(ClaudeRequestID)
  case allowOnce(ClaudeRequestID)
  case deny(ClaudeRequestID)
  case beginEditing
  case close
  case connect
  case disconnect
  case openLimits
  case filterWaiting(Bool)
  case nextWaiting
  case openInbox
  case closeInbox
  case attention(AttentionAction)
  case setCompact(Bool)
}
