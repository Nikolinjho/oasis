import Foundation
import IslandCore

extension CodexRequestsModule {
  func receive(_ event: CodexClientEvent) {
    switch event {
    case .connection(let state):
      connection = state
      panel.connected = state == .connected
      if case .waiting(let reason) = state { panel.error = reason } else { panel.error = nil }
    case .thread(let thread): updateThread(thread)
    case .threadClosed(let threadID): closeThread(threadID)
    case .question(let form): receiveQuestion(form)
    case .resolved(let identity):
      if let id = identities.first(where: { $0.value == identity })?.key { finish(id, phase: .continued) }
    case .invalidated(let generation): invalidate(generation)
    case .answerFailed(let identity):
      if let id = identities.first(where: { $0.value == identity })?.key {
        finish(id, phase: .disconnected)
        panel.error = "Ответ не подтверждён. Продолжи в терминале Codex."
      }
    }
    publish()
  }

  private func invalidate(_ generation: UUID) {
    for (id, identity) in identities where identity.generation == generation { finish(id, phase: .disconnected) }
    loadedThreads.removeAll()
    for index in panel.agents.indices where panel.agents[index].state != .closed { panel.agents[index].state = .stale }
  }

  private func updateThread(_ thread: CodexThreadSummary) {
    loadedThreads.insert(thread.id)
    let id = ClaudeAgentID(provider: "codex", sessionID: thread.id)
    let state: ClaudeAgentState
    switch thread.status.type {
    case "active": state = .working
    case "systemError": state = .error
    case "notLoaded": state = .closed
    default: state = .finished
    }
    let snapshot = ClaudeAgentSnapshot(
      id: id, project: URL(fileURLWithPath: thread.cwd).lastPathComponent,
      directory: thread.cwd, title: thread.name, state: state)
    if let index = panel.agents.firstIndex(where: { $0.id == id }) { panel.agents[index] = snapshot } else { panel.agents.append(snapshot) }
  }

  private func receiveQuestion(_ form: CodexQuestionnaire) {
    guard !identities.values.contains(form.id) else { return }
    let agent = ClaudeAgentID(provider: "codex", sessionID: form.id.threadID)
    if !panel.agents.contains(where: { $0.id == agent }) {
      panel.agents.append(.init(id: agent, project: "Codex", directory: "", state: .waiting))
    }
    let id = ClaudeRequestID(agent: agent)
    let questions = form.questions.map {
      ClaudeQuestion(
        text: $0.question, header: $0.header,
        options: ($0.options ?? []).map { .init(label: $0.label, description: $0.description) },
        multiSelect: false, isSecret: $0.isSecret, allowsOther: $0.isOther || ($0.options?.isEmpty ?? true))
    }
    panel.requests.append(
      .init(
        id: id, kind: .questions, toolName: "request_user_input", originalInput: Data(), questions: questions,
        deadline: .distantFuture, acceptsTerminalAnswer: true))
    identities[id] = form.id
    forms[id] = form
    publish()
    store.send(.alertArrived(.claudeRequest(id)))
  }

  private func closeThread(_ threadID: String) {
    loadedThreads.remove(threadID)
    for id in identities.keys where id.agent.sessionID == threadID { finish(id, phase: .cancelled) }
    for index in panel.agents.indices where panel.agents[index].id.sessionID == threadID { panel.agents[index].state = .closed }
  }

  func finish(_ id: ClaudeRequestID, phase: ClaudeRequestPhase) {
    guard let index = panel.requests.firstIndex(where: { $0.id == id }) else { return }
    if panel.requests[index].phase == .waiting || panel.requests[index].phase == .sending { panel.requests[index].phase = phase }
    panel.drafts[id] = nil
    forms[id] = nil
    if let agent = panel.agents.firstIndex(where: { $0.id == id.agent }), panel.agents[agent].state == .waiting {
      panel.agents[agent].state = .finished
    }
    store.send(.alertRetracted(.claudeRequest(id)))
  }
}
