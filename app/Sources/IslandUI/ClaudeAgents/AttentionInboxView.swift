import Foundation
import IslandCore
import SwiftUI

struct AttentionInboxView: View {
  let panel: ClaudeAgentsPanel
  let onAction: (ClaudeAgentsAction) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Входящие").font(.system(size: 15, weight: .semibold))
        Spacer()
        Button("К агентам") { onAction(.closeInbox) }
          .font(.system(size: 11)).buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
      }
      if panel.attention.isEmpty {
        Text("Новых событий пока нет").font(.system(size: 12)).foregroundStyle(IslandPalette.secondary)
      }
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 0) {
          ForEach(panel.attention) { item in
            VStack(alignment: .leading, spacing: 5) {
              Button {
                onAction(.attention(.open(item.id)))
              } label: {
                row(item)
              }
              .buttonStyle(.plain).disabled(!canOpen(item))
              if item.active { quickActions(item).padding(.leading, 15) }
            }
            .padding(.vertical, 7).opacity(item.active ? 1 : 0.5)
            Rectangle().fill(IslandPalette.divider).frame(height: 1)
          }
        }
      }
    }
    .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 18)
    .frame(width: 345, height: 175, alignment: .topLeading)
  }

  private func row(_ item: IslandAttention) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Circle().fill(item.unread && item.active ? ClaudeAgentsStyle.accent : IslandPalette.tertiary)
        .frame(width: 5, height: 5).padding(.top, 5)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.title).font(.system(size: 12, weight: .medium)).foregroundStyle(IslandPalette.foreground).lineLimit(2)
        Text(item.detail).font(.system(size: 10)).foregroundStyle(IslandPalette.secondary).lineLimit(1)
      }
      Spacer(minLength: 8)
      Text(item.observedAt, style: .time).font(.system(size: 9)).foregroundStyle(IslandPalette.tertiary)
      if canOpen(item) { Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(IslandPalette.tertiary) }
    }.contentShape(Rectangle())
  }

  @ViewBuilder
  private func quickActions(_ item: IslandAttention) -> some View {
    switch item.source {
    case .calendar(let event) where MeetingLink.find(in: event) != nil:
      Button("Войти") { onAction(.attention(.join(item.id))) }
        .font(.system(size: 10)).buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
    case .alert(.soon):
      HStack(spacing: 14) {
        Button("Готово") { onAction(.attention(.completeSoon(item.id))) }
        Button("+5 мин") { onAction(.attention(.snoozeSoon(item.id, seconds: 300))) }
      }.font(.system(size: 10)).buttonStyle(SoonTextButtonStyle(tint: SoonPalette.accent))
    default: EmptyView()
    }
  }

  private func canOpen(_ item: IslandAttention) -> Bool {
    switch item.source {
    case .alert(.claudeRequest): true
    case .calendar, .alert(.calendarReminder), .alert(.soon), .alert(.claude): item.active
    default: false
    }
  }
}
