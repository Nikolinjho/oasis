import AppKit
import Foundation
import SwiftUI

@MainActor
enum DebugCodexAgents {
  private static var window: NSWindow?

  static func section(_ module: CodexRequestsModule) -> DebugSection {
    DebugSection(
      title: "Codex Agents",
      entries: [
        .action(DebugAction(id: "codex.inspect", title: "Диагностика Codex") { show(module) }),
        .action(DebugAction(id: "codex.open", title: "Агенты Codex") { module.open() }),
        .action(DebugAction(id: "codex.connect", title: "Подключить Codex") { module.setEnabled(true) }),
      ])
  }

  private static func show(_ module: CodexRequestsModule) {
    let window =
      self.window
      ?? NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    self.window = window
    window.title = "Диагностика Codex"
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: CodexDiagnosticsView(module: module))
    window.center()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
}

private struct CodexDiagnosticsView: View {
  @ObservedObject var module: CodexRequestsModule

  var body: some View {
    ScrollView {
      Text(report).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.padding(20).frame(minWidth: 480, minHeight: 340)
  }

  private var report: String {
    var lines = [
      "Codex enabled: \(module.enabled), connected: \(module.panel.connected)",
      "Shared sessions: \(module.sessionCount)",
      "Requests: \(module.panel.requests.count), waiting: \(module.panel.waitingCount)",
      "View: \(module.store.model.expandedView.rawValue)",
      "Input active: \(module.store.agentInputActive)",
      "Queued peeks: \(module.store.queuedPeeks.count)",
      "Panel: \(Int(module.panel.width)) × \(Int(module.panel.height))",
    ]
    for request in module.panel.requests {
      lines.append("\(request.id.value.uuidString)  \(request.phase.rawValue)")
    }
    return lines.joined(separator: "\n")
  }
}

@MainActor
enum CodexAgentsLinkRouter {
  static func perform(_ url: URL, module: CodexRequestsModule) -> Bool {
    guard url.scheme == "oasis", url.host == "codex" else { return false }
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
