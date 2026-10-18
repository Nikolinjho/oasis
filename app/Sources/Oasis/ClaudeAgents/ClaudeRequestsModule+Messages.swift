import Foundation
import IslandCore

extension ClaudeRequestsModule {
  func receive(_ message: ClaudeBridgeMessage) {
    switch message {
    case .event(let event):
      guard seen.insert(event.eventID).inserted else { return }
      if seen.count > 4096 { seen = [event.eventID] }
      apply(event)
    case .request(let request): receiveRequest(request)
    case .received(let id, _): acceptRequest(id)
    case .cancelled(let id, let reason): cancelRequest(id, reason: reason)
    case .heartbeat(let id):
      if panel.agents.contains(where: { $0.id == id.agent }) { observations[id.agent] = Date() }
    default: break
    }
    publish()
  }

  private func receiveRequest(_ request: ClaudeRequest) {
    guard !panel.requests.contains(where: { $0.id == request.id }) else { return }
    guard panel.waiting.count < 64 else {
      bridge.cancel(requestID: request.id, reason: "capacity")
      return
    }
    if panel.agents.contains(where: {
      $0.id.sessionID == request.id.agent.sessionID && $0.state == .closed && $0.observedAt >= request.createdAt
    }) {
      bridge.cancel(requestID: request.id, reason: "session-ended")
      return
    }
    apply(.init(agent: request.id.agent, eventName: "Request", observedAt: request.createdAt, originalInput: request.originalInput))
    requestDeadlines[request.id] = .now.advanced(by: .seconds(min(590, max(0, request.deadline.timeIntervalSinceNow))))
    panel.requests.append(request)
    if panel.selectedAgentID == nil {
      panel.selectedAgentID = request.id.agent
      panel.selectedRequestID = request.id
    }
    if panel.selectedAgentID == request.id.agent, panel.selectedRequestID == nil { panel.selectedRequestID = request.id }
    publish()
    store.send(.alertArrived(.claudeRequest(request.id)))
  }

  private func acceptRequest(_ id: ClaudeRequestID) {
    guard let index = panel.requests.firstIndex(where: { $0.id == id }), panel.requests[index].phase == .sending else { return }
    panel.requests[index].phase = .accepted
    panel.drafts.removeValue(forKey: id)
    store.send(.alertRetracted(.claudeRequest(id)))
  }

  private func cancelRequest(_ id: ClaudeRequestID, reason: String) {
    guard let index = panel.requests.firstIndex(where: { $0.id == id }), isPending(panel.requests[index]) else { return }
    if reason == "expired" || requestDeadlines[id].map({ $0 <= .now }) == true {
      panel.requests[index].phase = .expired
    } else if reason == "cancelled" || reason == "session-ended" || reason == "subagent-stopped" {
      panel.requests[index].phase = .cancelled
    } else {
      panel.requests[index].phase = .disconnected
    }
    store.send(.alertRetracted(.claudeRequest(id)))
  }

  func disconnectRequests() {
    for index in panel.requests.indices where isPending(panel.requests[index]) {
      panel.requests[index].phase = .disconnected
      store.send(.alertRetracted(.claudeRequest(panel.requests[index].id)))
    }
  }

  func publish() {
    reconcileAgentStates()
    trimHistory()
    store.agentsPanel = panel
    let count = panel.waitingCount
    if store.model.agentsWaitingCount != count { store.send(.agentsWaitingChanged(count)) }
  }

  private func trimHistory() {
    let historical = panel.requests.filter { !isPending($0) && $0.id != panel.selectedRequestID }
      .sorted {
        let leftHasDraft = panel.drafts[$0.id] != nil
        let rightHasDraft = panel.drafts[$1.id] != nil
        if leftHasDraft != rightHasDraft { return leftHasDraft }
        return $0.createdAt > $1.createdAt
      }
    let removed = Set(historical.dropFirst(64).map(\.id))
    panel.requests.removeAll { removed.contains($0.id) }
    for id in removed {
      responseIDs.removeValue(forKey: id)
      requestDeadlines.removeValue(forKey: id)
      panel.drafts.removeValue(forKey: id)
    }
    trimAgents()
  }

  private func trimAgents() {
    let retained = Set(panel.waiting.map(\.id.agent)).union([panel.selectedAgentID].compactMap { $0 })
    let historical = panel.agents.filter { !retained.contains($0.id) }.sorted { $0.observedAt > $1.observedAt }
    let removed = Set(historical.dropFirst(max(0, 64 - retained.count)).map(\.id))
    panel.agents.removeAll { removed.contains($0.id) }
    for id in removed {
      observations.removeValue(forKey: id)
      eventDates.removeValue(forKey: id)
      settledStates.removeValue(forKey: id)
      branchDirectories.removeValue(forKey: id)
      branchDates.removeValue(forKey: id)
    }
  }

  func refreshFreshness() {
    let previous = panel
    for index in panel.requests.indices
    where isPending(panel.requests[index])
      && requestDeadlines[panel.requests[index].id].map({ $0 <= .now }) == true
    {
      let id = panel.requests[index].id
      panel.requests[index].phase = .expired
      bridge.cancel(requestID: id, reason: "expired")
      store.send(.alertRetracted(.claudeRequest(id)))
    }
    reconcileAgentStates()
    if panel != previous { publish() }
  }

  private func reconcileAgentStates() {
    for index in panel.agents.indices {
      let agent = panel.agents[index]
      let pending = panel.requests.contains { $0.id.agent == agent.id && isPending($0) }
      var state = settledStates[agent.id] ?? .working
      if state == .working, Date().timeIntervalSince(observations[agent.id] ?? agent.observedAt) > 45 { state = .stale }
      panel.agents[index].state = pending ? .waiting : state
    }
  }
}
