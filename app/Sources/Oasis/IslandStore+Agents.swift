import IslandCore

extension IslandStore {
  var waitingAgentCount: Int { agentsPanel.waitingCount + codexPanel.waitingCount }
  var activeAgentsPanel: ClaudeAgentsPanel { model.expandedView == .codexAgents ? codexPanel : agentsPanel }
  var allAgentRequests: [ClaudeRequest] { agentsPanel.requests + codexPanel.requests }

  func agentPanel(for id: ClaudeRequestID) -> ClaudeAgentsPanel {
    id.agent.provider == AgentProvider.codex.rawValue ? codexPanel : agentsPanel
  }

  func performAgentAction(_ action: ClaudeAgentsAction, provider: AgentProvider) {
    if provider == .codex { onCodexAction(action) } else { onAgentsAction(action) }
  }

  func publishAgentCount() {
    if model.agentsWaitingCount != waitingAgentCount { send(.agentsWaitingChanged(waitingAgentCount)) }
  }

  var codexWithAttention: ClaudeAgentsPanel {
    var snapshot = codexPanel
    snapshot.attention = attentionItems
    snapshot.showsInbox = showAttentionInbox
    return snapshot
  }
}
