import AppKit
import Combine
import IslandCore
import IslandSources

/// Реестр живых hook-запросов. Отправка всегда захватывает полный ID до await.
@MainActor
final class ClaudeRequestsModule: ObservableObject {
  @Published var panel = ClaudeAgentsPanel()
  let store: IslandStore
  let installer: ClaudeHooksInstaller
  let bridge = ClaudeBridgeSocket()
  var timer: Task<Void, Never>?
  var generation = UUID()
  var hasOpened = false
  var seen: Set<UUID> = []
  var requestDeadlines: [ClaudeRequestID: ContinuousClock.Instant] = [:]
  var responseIDs: [ClaudeRequestID: UUID] = [:]
  var observations: [ClaudeAgentID: Date] = [:]
  var eventDates: [ClaudeAgentID: Date] = [:]
  var settledStates: [ClaudeAgentID: ClaudeAgentState] = [:]
  var branchDates: [ClaudeAgentID: Date] = [:]
  var branchDirectories: [ClaudeAgentID: String] = [:]
  var onEditing: (Bool) -> Void = { _ in }
  var onOpen: () -> Void = {}

  init(store: IslandStore, installer: ClaudeHooksInstaller = .live) {
    self.store = store
    self.installer = installer
    panel.compact = UserDefaults.standard.bool(forKey: "claude.agents.compact")
    refreshConnection()
    store.onAgentsAction = { [weak self] action in self?.perform(action) }
  }

  func start() {
    guard timer == nil else { return }
    do {
      let current = UUID()
      generation = current
      try bridge.start { [weak self] message in
        Task { @MainActor in
          guard let self, self.generation == current else { return }
          self.receive(message)
        }
      }
      panel.error = nil
    } catch { panel.error = "Локальное подключение: \(error.localizedDescription)" }
    publish()
    timer = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        self?.refreshFreshness()
      }
    }
  }

  func stop() {
    timer?.cancel()
    timer = nil
    generation = UUID()
    branchDirectories.removeAll()
    branchDates.removeAll()
    bridge.stop()
    disconnectRequests()
    publish()
  }

  func refreshConnection() {
    panel.hasConnectionRecord = installer.hasConnectionRecord
    do {
      panel.connected = try installer.isInstalled()
      panel.hasForeignDecisionHooks = try installer.hasForeignDecisionHooks()
    } catch {
      panel.connected = false
      panel.error = error.localizedDescription
    }
    publish()
  }

  func open(requestID: ClaudeRequestID? = nil) {
    if let requestID {
      perform(.selectRequest(requestID))
    } else if !hasOpened, let request = panel.waiting.min(by: { $0.createdAt < $1.createdAt }) {
      panel.selectedAgentID = request.id.agent
      panel.selectedRequestID = request.id
    }
    hasOpened = true
    let ranks: [ClaudeAgentState: Int] = [.waiting: 0, .working: 1, .error: 2, .finished: 3, .stale: 4, .closed: 5]
    panel.agents = panel.agents.enumerated().sorted {
      let left = ranks[$0.element.state, default: 6]
      let right = ranks[$1.element.state, default: 6]
      return left == right ? $0.offset < $1.offset : left < right
    }.map(\.element)
    publish()
    store.send(.expandedViewRequested(.agents))
    onOpen()
  }

  func editable(_ id: ClaudeRequestID) -> ClaudeRequest? {
    panel.requests.first { $0.id == id && $0.phase == .waiting && requestDeadlines[id].map { $0 > .now } == true }
  }
  func isPending(_ request: ClaudeRequest) -> Bool { request.phase == .waiting || request.phase == .sending }
  func requests(for id: ClaudeAgentID) -> [ClaudeRequest] {
    panel.requests.filter { $0.id.agent == id }.sorted {
      if isPending($0) != isPending($1) { return isPending($0) }
      return $0.createdAt > $1.createdAt
    }
  }

  func submit(_ id: ClaudeRequestID, answer: ClaudeAnswer) {
    guard let index = panel.requests.firstIndex(where: { $0.id == id }), editable(id) != nil else { return }
    let responseID = responseIDs[id] ?? UUID()
    responseIDs[id] = responseID
    panel.requests[index].phase = .sending
    panel.error = nil
    publish()
    let current = generation
    Task { [weak self, bridge] in
      do {
        try await bridge.respond(requestID: id, responseID: responseID, answer: answer)
        guard let self, generation == current, let index = panel.requests.firstIndex(where: { $0.id == id }) else { return }
        guard [.sending, .accepted, .continued].contains(panel.requests[index].phase) else { return }
        if case .deny = answer {
          panel.requests[index].phase = .declined
        } else if panel.requests[index].phase != .continued {
          panel.requests[index].phase = .accepted
        }
        panel.drafts.removeValue(forKey: id)
        store.send(.alertRetracted(.claudeRequest(id)))
        publish()
      } catch {
        guard let self, generation == current, let index = panel.requests.firstIndex(where: { $0.id == id }) else { return }
        guard panel.requests[index].phase == .sending else { return }
        panel.requests[index].phase = .disconnected
        store.send(.alertRetracted(.claudeRequest(id)))
        panel.error = "Ответ не подтверждён. Продолжи в Claude Code."
        publish()
      }
    }
  }

}
