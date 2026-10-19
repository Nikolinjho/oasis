import IslandCore

extension CodexRequestsModule {
  func perform(_ action: ClaudeAgentsAction) {
    switch action {
    case .openPanel: open()
    case .openRequest(let id): open(requestID: id)
    case .beginEditing: onEditing(true)
    case .close:
      onEditing(false)
      store.onSwipeClose()
      store.send(.clickedOutside)
    case .openInbox:
      onEditing(false)
      store.showAttentionInbox = true
      store.attentionInboxProvider = .codex
      store.send(.expandedViewRequested(.inbox))
    case .closeInbox:
      store.showAttentionInbox = false
      store.send(.expandedViewRequested(.codexAgents))
    case .attention(let action):
      onEditing(false)
      store.performAttention(action)
    default:
      if !performEditing(action) { performSelection(action) }
    }
    publish()
  }

  private func performEditing(_ action: ClaudeAgentsAction) -> Bool {
    switch action {
    case .selectAgent(let id):
      onEditing(false)
      panel.selectedAgentID = id
      panel.selectedRequestID = panel.requests.last { $0.id.agent == id }?.id
    case .selectRequest(let id): selectRequest(id)
    case .selectQuestion(let id, let index):
      guard let request = editable(id), request.questions.indices.contains(index) else { return true }
      panel.drafts[id, default: .init()].questionIndex = index
    case .toggleOption(let id, let question, let option): toggleOption(id, question: question, option: option)
    case .text(let id, let question, let value): updateText(id, question: question, value: value)
    case .textPosition(let id, let question, let position):
      guard editable(id) != nil else { return true }
      panel.drafts[id, default: .init()].positions[question] = position
    case .send(let id): send(id)
    default: return false
    }
    return true
  }

  private func performSelection(_ action: ClaudeAgentsAction) {
    switch action {
    case .connect: setEnabled(true)
    case .disconnect: setEnabled(false)
    case .setCompact(let compact):
      panel.compact = compact
      defaults.set(compact, forKey: "codex.agents.compact")

    case .filterWaiting(let waiting): panel.waitingOnly = waiting
    case .nextWaiting:
      if let request = panel.waiting.min(by: { $0.createdAt < $1.createdAt }) { selectRequest(request.id) }
    default: break
    }
  }

  func selectRequest(_ id: ClaudeRequestID) {
    guard panel.requests.contains(where: { $0.id == id }) else { return }
    onEditing(false)
    panel.selectedAgentID = id.agent
    panel.selectedRequestID = id
  }

  private func editable(_ id: ClaudeRequestID) -> ClaudeRequest? {
    panel.requests.first { $0.id == id && $0.phase == .waiting && forms[id] != nil }
  }

  private func updateText(_ id: ClaudeRequestID, question: Int, value: String) {
    guard let request = editable(id), request.questions.indices.contains(question),
      request.questions[question].allowsOther || request.questions[question].options.isEmpty
    else { return }
    panel.drafts[id, default: .init()].texts[question] = String(value.prefix(32_768))
    if !value.isEmpty { panel.drafts[id, default: .init()].options[question] = [] }
  }

  private func toggleOption(_ id: ClaudeRequestID, question: Int, option: Int) {
    guard let request = editable(id), request.questions.indices.contains(question),
      request.questions[question].options.indices.contains(option)
    else { return }
    let selected = panel.drafts[id, default: .init()].options[question, default: []]
    panel.drafts[id, default: .init()].options[question] = selected == [option] ? [] : [option]
    panel.drafts[id, default: .init()].texts[question] = ""
  }

  private func send(_ id: ClaudeRequestID) {
    guard let request = editable(id), let form = forms[id], let identity = identities[id],
      panel.drafts[id, default: .init()].answer(for: request) != nil,
      let index = panel.requests.firstIndex(where: { $0.id == id })
    else { return }
    let draft = panel.drafts[id, default: .init()]
    var answers: [String: [String]] = [:]
    for (questionIndex, question) in form.questions.enumerated() {
      let text = draft.texts[questionIndex] ?? ""
      if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        answers[question.id] = [text]
      } else {
        answers[question.id] = (draft.options[questionIndex] ?? []).sorted().map { request.questions[questionIndex].options[$0].label }
      }
    }
    panel.requests[index].phase = .sending
    publish()
    let queued = client.answer(identity, answers: answers)
    panel.drafts[id] = nil
    if !queued { finish(id, phase: .disconnected) }
    onEditing(false)
  }
}
