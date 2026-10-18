import Foundation

@MainActor
enum DebugClaudeAgents {
  static func section(_ module: ClaudeRequestsModule) -> DebugSection {
    DebugSection(
      title: "Claude Agents",
      entries: [
        .action(DebugAction(id: "agents.inspect", title: "Диагностика агентов") { ClaudeAgentsDiagnostics.show(module) }),
        .action(DebugAction(id: "agents.open", title: "Агенты и ответы") { module.open() }),
        .action(DebugAction(id: "agents.compact", title: "Компактная панель агентов") { module.perform(.setCompact(true)) }),
        .action(DebugAction(id: "agents.large", title: "Большая панель агентов") { module.perform(.setCompact(false)) }),
      ])
  }
}

@MainActor
enum ClaudeAgentsLinkRouter {
  static func perform(_ url: URL, module: ClaudeRequestsModule) -> Bool {
    guard url.scheme == "oasis", url.host == "agents" else { return false }
    guard url.path.isEmpty || url.path == "/open" else { return true }
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    if let raw = items.first(where: { $0.name == "request" })?.value {
      guard let value = UUID(uuidString: raw), let request = module.panel.requests.first(where: { $0.id.value == value }) else {
        return true
      }
      module.open(requestID: request.id)
    } else {
      module.open()
    }
    return true
  }
}
