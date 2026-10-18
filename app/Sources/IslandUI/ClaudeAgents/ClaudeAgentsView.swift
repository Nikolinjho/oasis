import IslandCore
import SwiftUI

struct ClaudeAgentsView: View {
  let panel: ClaudeAgentsPanel
  let onAction: (ClaudeAgentsAction) -> Void
  let onOpenSettings: () -> Void
  var context: CalendarEvent?
  var music: NowPlayingInfo?
  var soonCount = 0
  var onJoin: (URL) -> Void = { _ in }

  private var sidebarWidth: CGFloat { panel.compact ? 164 : 184 }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      sidebar.frame(width: sidebarWidth)
      Rectangle().fill(IslandPalette.divider).frame(width: 1).padding(.horizontal, 14)
      VStack(alignment: .leading, spacing: 8) {
        if context != nil || music?.isPlaying == true || soonCount > 0 { contextLine }
        if let agent = panel.selectedAgent {
          detailHeader(agent)
          if panel.waitingOnly && agent.state != .waiting {
            Text("Выбранный агент скрыт фильтром").font(.system(size: 9)).foregroundStyle(IslandPalette.tertiary)
          }
          if let request = panel.selectedRequest {
            ClaudeRequestDetail(panel: panel, request: request, onAction: onAction)
              .id(request.id)
          } else {
            stateDetail(agent)
          }
        } else {
          empty
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .padding(.horizontal, 24)
    .padding(.top, 5)
    .padding(.bottom, 18)
    .foregroundStyle(IslandPalette.foreground)
    .frame(width: panel.width, height: panel.height - ExpandedLayout.headerHeight, alignment: .top)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("CLAUDE CODE").font(.system(size: 10, weight: .semibold)).tracking(0.8)
        Spacer()
        Text("\(panel.waitingCount) ждут").font(.system(size: 10)).foregroundStyle(ClaudeAgentsStyle.accent)
      }
      .foregroundStyle(IslandPalette.secondary)
      .padding(.horizontal, 10)
      if panel.agents.isEmpty {
        Text("Сессии появятся после подключения hooks и нового события Claude Code.")
          .font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
          .padding(.horizontal, 10).padding(.top, 6)
      }
      HStack(spacing: 12) {
        filter("Все", waiting: false)
        filter("Ждут", waiting: true)
      }.padding(.horizontal, 10)
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 0) {
          ForEach(panel.agents.filter { !panel.waitingOnly || $0.state == .waiting }) { agent in
            Button {
              onAction(.selectAgent(agent.id))
            } label: {
              agentRow(agent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(agent.project), \(agent.state.title), \(agent.id.sessionID.prefix(8))")
          }
        }
      }
      HStack(spacing: 12) {
        Button("Лимиты") { onAction(.openLimits) }
        Button("Входящие · \(panel.attention.filter { $0.active && $0.unread }.count)") { onAction(.openInbox) }
        Spacer(minLength: 0)
      }
      .font(.system(size: 10)).buttonStyle(SoonTextButtonStyle(tint: IslandPalette.secondary))
      .padding(.horizontal, 10)
    }
  }

  private func filter(_ title: String, waiting: Bool) -> some View {
    Button {
      onAction(.filterWaiting(waiting))
    } label: {
      Text(title).font(.system(size: 10, weight: .medium))
        .foregroundStyle(panel.waitingOnly == waiting ? IslandPalette.foreground : IslandPalette.tertiary)
        .underline(panel.waitingOnly == waiting, color: ClaudeAgentsStyle.accent.opacity(0.7))
    }.buttonStyle(.plain)
  }

  private func agentRow(_ agent: ClaudeAgentSnapshot) -> some View {
    HStack(spacing: 7) {
      Circle().fill(ClaudeAgentsStyle.color(agent.state)).frame(width: 5, height: 5)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 5) {
          if agent.parent != nil { Image(systemName: "arrow.turn.down.right").font(.system(size: 8)) }
          Text(agent.project).font(.system(size: 12, weight: .semibold)).lineLimit(1)
        }
        HStack(spacing: 5) {
          Text(agent.branch ?? agent.state.title).foregroundStyle(ClaudeAgentsStyle.color(agent.state))
          Text(String((agent.id.agentID ?? agent.id.sessionID).prefix(6))).foregroundStyle(IslandPalette.tertiary)
        }.font(.system(size: 9)).lineLimit(1)
      }
      Spacer(minLength: 0)
      let count = panel.waiting.filter { $0.id.agent == agent.id }.count
      if count > 0 { Text("\(count)").font(.system(size: 10, weight: .semibold)).foregroundStyle(ClaudeAgentsStyle.accent) }
    }
    .padding(.horizontal, 10).frame(height: 42)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 6).fill(panel.selectedAgentID == agent.id ? IslandPalette.pressed : .clear))
    .contentShape(Rectangle())
    .help("Сессия: \(agent.id.sessionID)" + (agent.id.agentID.map { " · Агент: \($0)" } ?? ""))
  }

  private var contextLine: some View {
    HStack(spacing: 6) {
      if let context {
        Image(systemName: "calendar")
        Text(context.start <= Date() ? "Созвон начался · \(context.title)" : context.title).lineLimit(1)
        if let url = MeetingLink.find(in: context) {
          Button("Войти") { onJoin(url) }.buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
        }
      }
      Spacer(minLength: 0)
      if let music, music.isPlaying { Image(systemName: music.isPlaying ? "waveform" : "pause.fill").help(music.title) }
      if soonCount > 0 { Text("Soon · \(soonCount)").fixedSize() }
    }
    .font(.system(size: 10)).foregroundStyle(IslandPalette.secondary).frame(height: 18)
  }

  private func detailHeader(_ agent: ClaudeAgentSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(agent.project).font(.system(size: 15, weight: .semibold)).lineLimit(1)
        Spacer()
        Text(agent.state.title).font(.system(size: 10)).foregroundStyle(ClaudeAgentsStyle.color(agent.state))
      }
      HStack(spacing: 6) {
        if let branch = agent.branch {
          Text(branch)
          Text("·")
        }
        if let title = agent.title {
          Text(title)
          Text("·")
        }
        Text(String(agent.id.sessionID.prefix(8)))
        if let id = agent.id.agentID {
          Text("·")
          Text(String(id.prefix(8)))
        }
      }
      .font(.system(size: 10)).foregroundStyle(IslandPalette.tertiary).lineLimit(1)
      .textSelection(.enabled)
      .help("Сессия: \(agent.id.sessionID)" + (agent.id.agentID.map { " · Агент: \($0)" } ?? ""))
    }
  }

  private func stateDetail(_ agent: ClaudeAgentSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(agent.detail.isEmpty ? agent.state.title : agent.detail)
        .font(.system(size: 12)).foregroundStyle(IslandPalette.secondary).lineLimit(5)
      Text("Ответить здесь можно, когда Claude задаст вопрос или запросит разрешение.")
        .font(.system(size: 11)).foregroundStyle(IslandPalette.tertiary)
      Spacer()
    }.padding(.top, 12)
  }

  private var empty: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Агенты и ответы").font(.system(size: 18, weight: .semibold))
      Text("Вопросы и разовые разрешения Claude Code появятся в острове. Музыка и календарь останутся рядом.")
        .font(.system(size: 12)).foregroundStyle(IslandPalette.secondary)
      if let error = panel.error { Text(error).font(.system(size: 11)).foregroundStyle(IslandPalette.dateAccent) }
      if panel.connected {
        Text("Подключено · начни новую сессию Claude Code").font(.system(size: 11)).foregroundStyle(ClaudeAgentsStyle.accent)
      } else {
        Button("Подключить Claude Code") { onAction(.connect) }
          .font(.system(size: 12)).buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
      }
      Spacer()
      Button("Настройки") { onOpenSettings() }.font(.system(size: 11)).buttonStyle(SoonTextButtonStyle(tint: IslandPalette.secondary))
    }.padding(.top, 12)
  }
}

enum ClaudeAgentsStyle {
  static let accent = Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
  static func color(_ state: ClaudeAgentState) -> Color {
    switch state {
    case .waiting: accent
    case .working: IslandPalette.charging
    case .error: IslandPalette.dateAccent
    case .finished: IslandPalette.secondary
    case .stale, .closed: IslandPalette.tertiary
    }
  }
}
