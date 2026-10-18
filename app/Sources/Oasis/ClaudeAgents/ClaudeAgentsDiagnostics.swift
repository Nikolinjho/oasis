import AppKit
import IslandCore
import SwiftUI

@MainActor
enum ClaudeAgentsDiagnostics {
  private static var window: NSWindow?

  static func show(_ module: ClaudeRequestsModule) {
    let window =
      self.window
      ?? NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    self.window = window
    window.title = "Диагностика Claude Code"
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: ClaudeAgentsDiagnosticsView(module: module))
    window.center()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
}

private struct ClaudeAgentsDiagnosticsView: View {
  @ObservedObject var module: ClaudeRequestsModule

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Claude Code · локальное подключение").font(.headline)
        Spacer()
        Button("Обновить") { module.refreshConnection() }
      }
      ScrollView {
        Text(report).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }.padding(20).frame(minWidth: 480, minHeight: 340)
  }

  private var report: String {
    let panel = module.panel
    let time = DateFormatter()
    time.locale = Locale(identifier: "en_US_POSIX")
    time.dateFormat = "HH:mm:ss"
    time.timeZone = TimeZone(identifier: "Europe/Moscow")
    var lines = [
      "Protocol: \(ClaudeBridgeLimits.protocolVersion)",
      "Hooks connected: \(panel.connected)",
      "Agents: \(panel.agents.count), requests: \(panel.requests.count), waiting: \(panel.waitingCount)",
      "Input active: \(module.store.agentInputActive)",
      "Surface: \(String(describing: module.store.model.surface)), fullscreen: \(module.store.model.isFullscreen)",
      "Base: \(String(describing: module.store.model.base)), pending: \(String(describing: module.store.model.pending))",
      "View: \(module.store.model.expandedView.rawValue), calendar: \(module.store.model.calendarLive), media: \(module.store.model.showsMedia)",
      "Leases: \(module.store.attention.leases.count), restore: \(String(describing: module.store.attention.restoreView))",
      "Panel: \(Int(panel.width)) × \(Int(panel.height))",
      "",
      "Agents · time MSK:",
    ]
    for agent in panel.agents {
      let identity = String(agent.id.sessionID.prefix(8)) + (agent.id.agentID.map { "/" + String($0.prefix(8)) } ?? "")
      lines.append("\(identity)  \(agent.state.rawValue)  \(time.string(from: agent.observedAt))")
    }
    lines.append("\nRequests:")
    for request in panel.requests {
      lines.append("\(request.id.value.uuidString)  \(request.kind.rawValue)  \(request.phase.rawValue)")
    }
    return lines.joined(separator: "\n")
  }
}
