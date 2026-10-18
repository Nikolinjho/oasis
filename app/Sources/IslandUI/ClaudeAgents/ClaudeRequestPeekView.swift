import IslandCore
import SwiftUI

struct ClaudeRequestPeekView: View {
  let panel: ClaudeAgentsPanel
  let requestID: ClaudeRequestID
  let notchWidth: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        ActivityIcon(layout: ActivityLayouts.claudeIcon).frame(width: 18, height: 15)
        Spacer(minLength: notchWidth)
        Text("\(panel.waitingCount) ждут").font(.system(size: 11, weight: .semibold)).foregroundStyle(ClaudeAgentsStyle.accent)
      }
      .padding(.horizontal, 24).frame(height: 32)
      HStack(spacing: 7) {
        Rectangle().fill(ClaudeAgentsStyle.accent).frame(width: 2, height: 17)
        VStack(alignment: .leading, spacing: 2) {
          Text(agent?.project ?? "Claude Code").font(.system(size: 10)).foregroundStyle(IslandPalette.secondary)
          Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(IslandPalette.foreground).lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(IslandPalette.tertiary)
      }
      .padding(.horizontal, 24).frame(height: 41.5)
    }.accessibilityLabel("Claude ждёт ответа: \(title)")
  }

  private var request: ClaudeRequest? { panel.requests.first { $0.id == requestID } }
  private var agent: ClaudeAgentSnapshot? { panel.agents.first { $0.id == requestID.agent } }
  private var title: String {
    guard let request else { return "Запрос больше не доступен" }
    return request.kind == .permission ? "Разрешение: \(request.toolName)" : request.questions.first?.text ?? "Claude спрашивает"
  }
}
