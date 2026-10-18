import Foundation
import IslandCore

extension ClaudeRequestsModule {
  func apply(_ event: ClaudeBridgeEvent) {
    let id = event.agent
    if event.eventName == "SubagentStop", !panel.agents.contains(where: { $0.id == id }) { return }
    if let previous = eventDates[id], previous > event.observedAt {
      if event.eventName == "SessionEnd" { closeSession(event) }
      return
    }
    eventDates[id] = event.observedAt
    observations[id] = max(observations[id] ?? event.observedAt, event.observedAt)
    let object = (try? JSONSerialization.jsonObject(with: event.originalInput)) as? [String: Any] ?? [:]
    let index = updateAgent(event, object: object)
    applyState(event, object: object, index: index)
    continueRequests(event, toolUseID: object["tool_use_id"] as? String)
    refreshBranch(for: panel.agents[index])
  }

  private func updateAgent(_ event: ClaudeBridgeEvent, object: [String: Any]) -> Int {
    let id = event.agent
    let directory = String((object["cwd"] as? String ?? "").prefix(4096))
    if !panel.agents.contains(where: { $0.id == id }) {
      panel.agents.append(
        .init(
          id: id, project: directory.isEmpty ? "Claude Code" : URL(fileURLWithPath: directory).lastPathComponent,
          directory: directory, observedAt: event.observedAt))
      if panel.selectedAgentID == nil { panel.selectedAgentID = id }
    }
    let index = panel.agents.firstIndex(where: { $0.id == id })!
    panel.agents[index].observedAt = event.observedAt
    if event.eventName == "SubagentStart" { panel.agents[index].parent = ClaudeAgentID(sessionID: id.sessionID) }
    if !directory.isEmpty {
      panel.agents[index].directory = directory
      panel.agents[index].project = URL(fileURLWithPath: directory).lastPathComponent
    }
    if let title = object["agent_type"] as? String { panel.agents[index].title = String(title.prefix(256)) }
    return index
  }

  private func applyState(_ event: ClaudeBridgeEvent, object: [String: Any], index: Int) {
    switch event.eventName {
    case "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStart":
      settledStates[event.agent] = .working
      panel.agents[index].detail = String((object["tool_name"] as? String ?? "").prefix(256))
    case "Stop", "SubagentStop":
      settledStates[event.agent] = .finished
      if event.eventName == "SubagentStop" { closeSubagentRequests(event) }
      panel.agents[index].detail = "Ход завершён. Следующий вопрос появится после нового запроса в Claude Code."
    case "SessionEnd": closeSession(event)
    case "PostToolUseFailure", "StopFailure":
      settledStates[event.agent] = .error
      panel.agents[index].detail = String(
        (object["error"] as? String ?? object["error_details"] as? String ?? "Claude завершился с ошибкой").prefix(1000))
    case "Notification":
      panel.agents[index].detail = String((object["message"] as? String ?? "Уведомление Claude Code").prefix(1000))
    default: break
    }
  }

  private func closeSession(_ event: ClaudeBridgeEvent) {
    for index in panel.agents.indices where panel.agents[index].id.sessionID == event.agent.sessionID {
      guard panel.agents[index].observedAt <= event.observedAt else { continue }
      let id = panel.agents[index].id
      panel.agents[index].observedAt = event.observedAt
      eventDates[id] = event.observedAt
      settledStates[id] = .closed
    }
    for index in panel.requests.indices where panel.requests[index].id.agent.sessionID == event.agent.sessionID {
      let request = panel.requests[index]
      guard isPending(request), request.createdAt <= event.observedAt else { continue }
      panel.requests[index].phase = .cancelled
      bridge.cancel(requestID: request.id, reason: "session-ended")
      store.send(.alertRetracted(.claudeRequest(request.id)))
    }
  }

  private func closeSubagentRequests(_ event: ClaudeBridgeEvent) {
    for index in panel.requests.indices {
      let request = panel.requests[index]
      guard request.id.agent == event.agent, isPending(request), request.createdAt <= event.observedAt else { continue }
      panel.requests[index].phase = .cancelled
      bridge.cancel(requestID: request.id, reason: "subagent-stopped")
      store.send(.alertRetracted(.claudeRequest(request.id)))
    }
  }

  private func continueRequests(_ event: ClaudeBridgeEvent, toolUseID: String?) {
    guard event.eventName == "PostToolUse" || event.eventName == "PostToolUseFailure", let toolUseID else { return }
    for index in panel.requests.indices {
      let request = panel.requests[index]
      guard request.id.agent == event.agent, request.phase == .accepted,
        request.toolUseID == toolUseID, request.createdAt <= event.observedAt
      else { continue }
      panel.requests[index].phase = .continued
    }
  }
}
