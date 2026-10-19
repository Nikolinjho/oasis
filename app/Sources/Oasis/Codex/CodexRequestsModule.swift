import Combine
import Foundation
import IslandCore
import IslandSources

@MainActor
final class CodexRequestsModule: ObservableObject {
  @Published var panel = ClaudeAgentsPanel(provider: .codex)
  @Published private(set) var enabled: Bool
  @Published var connection = CodexConnectionState.stopped
  let store: IslandStore
  let client = CodexAppServerClient()
  let defaults: UserDefaults
  var identities: [ClaudeRequestID: CodexQuestionIdentity] = [:]
  var forms: [ClaudeRequestID: CodexQuestionnaire] = [:]
  var loadedThreads: Set<String> = []
  var onEditing: (Bool) -> Void = { _ in }

  init(store: IslandStore, defaults: UserDefaults = .standard) {
    self.store = store
    self.defaults = defaults
    enabled = defaults.bool(forKey: "codex.agents.enabled")
    panel.compact = defaults.bool(forKey: "codex.agents.compact")
    store.onCodexAction = { [weak self] in self?.perform($0) }
    publish()
  }

  var sessionCount: Int { loadedThreads.count }
  var connectionTitle: String {
    switch connection {
    case .stopped: "Подключение выключено"
    case .connecting: "Подключение к Codex…"
    case .connected: "Общий сервер Codex подключён"
    case .waiting: "Ожидаем общий сервер Codex"
    }
  }

  func start() {
    guard enabled else { return }
    client.start { [weak self] in self?.receive($0) }
  }

  func stop() {
    onEditing(false)
    client.stop()
  }

  func setEnabled(_ value: Bool) {
    enabled = value
    defaults.set(value, forKey: "codex.agents.enabled")
    if value { start() } else { stop() }
  }

  func open(requestID: ClaudeRequestID? = nil) {
    onEditing(false)
    if let requestID { selectRequest(requestID) }
    if panel.selectedAgentID == nil {
      if let request = panel.waiting.min(by: { $0.createdAt < $1.createdAt }) {
        selectRequest(request.id)
      } else {
        panel.selectedAgentID = panel.agents.first?.id
      }
    }
    store.showAttentionInbox = false
    publish()
    store.send(.expandedViewRequested(.codexAgents))
  }

  func publish() {
    for index in panel.agents.indices where panel.waiting.contains(where: { $0.id.agent == panel.agents[index].id }) {
      panel.agents[index].state = .waiting
    }
    trimHistory()
    store.codexPanel = panel
    store.publishAgentCount()
  }

  private func trimHistory() {
    let finished = panel.requests.filter { $0.phase != .waiting && $0.phase != .sending && $0.id != panel.selectedRequestID }
      .sorted { $0.createdAt > $1.createdAt }
    let removed = Set(finished.dropFirst(64).map(\.id))
    panel.requests.removeAll { removed.contains($0.id) }
    for id in removed {
      identities[id] = nil
      forms[id] = nil
      panel.drafts[id] = nil
    }
    let retained = Set(panel.requests.map { $0.id.agent }).union(loadedThreads.map { ClaudeAgentID(provider: "codex", sessionID: $0) })
    let historical = panel.agents.filter { !retained.contains($0.id) && $0.id != panel.selectedAgentID }
      .sorted { $0.observedAt > $1.observedAt }
    let removedAgents = Set(historical.dropFirst(64).map(\.id))
    panel.agents.removeAll { removedAgents.contains($0.id) }
  }
}
