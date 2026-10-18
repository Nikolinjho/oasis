import AppKit
import IslandCore

extension ClaudeRequestsModule {
  // swiftlint:disable:next cyclomatic_complexity - таблица явных действий панели
  func perform(_ action: ClaudeAgentsAction) {
    switch action {
    case .openPanel: open()
    case .openRequest(let id): open(requestID: id)
    case .connect: connect()
    case .disconnect: disconnect()
    case .selectAgent(let id):
      panel.selectedAgentID = id
      panel.selectedRequestID = requests(for: id).first?.id
    case .selectRequest(let id): selectRequest(id)
    case .selectQuestion(let id, let index): selectQuestion(id, index: index)
    case .toggleOption(let id, let index, let option): toggleOption(id, questionIndex: index, option: option)
    case .text(let id, let index, let value): updateText(id, index: index, value: value)
    case .textPosition(let id, let index, let position):
      guard panel.requests.contains(where: { $0.id == id }) else { return }
      panel.drafts[id, default: .init()].positions[index] = position
    case .send(let id): sendDraft(id)
    case .allowOnce(let id): submitPermission(id, answer: .allowOnce)
    case .deny(let id): submitPermission(id, answer: .deny(message: "Отклонено пользователем в Oasis"))
    case .beginEditing: onEditing(true)
    case .close:
      onEditing(false)
      store.onSwipeClose()
      store.send(.clickedOutside)
    case .openLimits:
      onEditing(false)
      store.send(.expandedViewRequested(.claude))
    case .filterWaiting(let value): panel.waitingOnly = value
    case .nextWaiting:
      if let next = panel.waiting.min(by: { $0.createdAt < $1.createdAt }) { selectRequest(next.id) }
    case .openInbox:
      onEditing(false)
      store.showAttentionInbox = true
      store.send(.expandedViewRequested(.inbox))
    case .closeInbox:
      store.showAttentionInbox = false
      store.send(.expandedViewRequested(.agents))
    case .attention(let action):
      onEditing(false)
      store.performAttention(action)
    case .setCompact(let compact):
      panel.compact = compact
      UserDefaults.standard.set(compact, forKey: "claude.agents.compact")
    }
    publish()
  }

  private func connect() {
    do {
      try installer.install()
      panel.error = nil
    } catch { panel.error = error.localizedDescription }
    refreshConnection()
  }

  private func disconnect() {
    do {
      try installer.uninstall()
      panel.error = nil
    } catch { panel.error = error.localizedDescription }
    stop()
    refreshConnection()
    start()
  }

  private func selectRequest(_ id: ClaudeRequestID) {
    guard panel.requests.contains(where: { $0.id == id }) else { return }
    panel.selectedAgentID = id.agent
    panel.selectedRequestID = id
  }

  private func selectQuestion(_ id: ClaudeRequestID, index: Int) {
    guard let request = panel.requests.first(where: { $0.id == id }), request.questions.indices.contains(index) else { return }
    panel.drafts[id, default: .init()].questionIndex = index
  }

  private func toggleOption(_ id: ClaudeRequestID, questionIndex: Int, option: Int) {
    guard let request = editable(id), request.questions.indices.contains(questionIndex),
      request.questions[questionIndex].options.indices.contains(option)
    else { return }
    var draft = panel.drafts[id, default: .init()]
    let selected = draft.options[questionIndex, default: []]
    if request.questions[questionIndex].multiSelect {
      draft.options[questionIndex] = selected.contains(option) ? selected.subtracting([option]) : selected.union([option])
    } else {
      draft.options[questionIndex] = selected == [option] ? [] : [option]
    }
    draft.texts[questionIndex] = ""
    panel.drafts[id] = draft
  }

  private func updateText(_ id: ClaudeRequestID, index: Int, value: String) {
    guard let request = editable(id), request.questions.indices.contains(index) else { return }
    panel.drafts[id, default: .init()].texts[index] = String(value.prefix(32_768))
    if !value.isEmpty { panel.drafts[id, default: .init()].options[index] = [] }
  }

  private func sendDraft(_ id: ClaudeRequestID) {
    guard let request = editable(id), let answer = panel.drafts[id, default: .init()].answer(for: request) else { return }
    submit(id, answer: answer)
  }

  private func submitPermission(_ id: ClaudeRequestID, answer: ClaudeAnswer) {
    guard editable(id)?.kind == .permission else { return }
    submit(id, answer: answer)
  }
}
