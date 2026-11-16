import IslandCore
import SwiftUI

struct ModulesView: View {
  let mediaEnabled: Bool
  let calendarEnabled: Bool
  let claudeAvailable: Bool
  let codexAvailable: Bool
  let soonAvailable: Bool
  let onSelectView: (ExpandedView) -> Void
  var notchWidth: CGFloat = 185

  var body: some View {
    HStack(spacing: 8) {
      if mediaEnabled && calendarEnabled {
        tile("Duo", subtitle: "Музыка и события", symbol: "rectangle.split.2x1", view: .duo)
      }
      if mediaEnabled { tile("Музыка", subtitle: "Плеер", symbol: "music.note", view: .player) }
      if calendarEnabled { tile("Календарь", subtitle: "События и месяц", symbol: "calendar", view: .calendar) }
      if claudeAvailable { tile("Claude Code", subtitle: "Лимиты подписки", symbol: "sparkle", view: .claude) }
      if codexAvailable { tile("Codex", subtitle: "Лимиты подписки", symbol: "terminal", view: .codex) }
      if soonAvailable { tile("Soon", subtitle: "Напоминания", symbol: "clock.arrow.circlepath", view: .soon) }
    }
    .padding(.horizontal, 24)
    .frame(width: layout.size(for: .modules).width, height: ExpandedLayout.dashboard.height - ExpandedLayout.headerHeight)
  }

  private var layout: DashboardLayout {
    DashboardLayout(
      media: mediaEnabled, calendar: calendarEnabled, claude: claudeAvailable, codex: codexAvailable,
      soon: soonAvailable, notchWidth: notchWidth)
  }

  private func tile(_ title: String, subtitle: String, symbol: String, view: ExpandedView) -> some View {
    ModuleTile(title: title, subtitle: subtitle, symbol: symbol, enabled: true) {
      onSelectView(view)
    }
  }
}

private struct ModuleTile: View {
  let title: String
  let subtitle: String
  let symbol: String
  let enabled: Bool
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        Group {
          if title == "Soon" {
            SoonIcon().frame(width: 36, height: 36)
          } else {
            Image(systemName: symbol)
              .font(.system(size: 28, weight: .regular))
              .foregroundStyle(title == "Claude Code" ? .orange : IslandPalette.foreground)
          }
        }
        .frame(height: 36)
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(IslandPalette.foreground)
        Text(subtitle)
          .font(.system(size: 10))
          .foregroundStyle(IslandPalette.secondary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 126)
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(HoverBackgroundStyle(isHovered: isHovered && enabled))
    .onHover { isHovered = $0 }
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.38)
    .accessibilityLabel("\(title), \(subtitle)")
  }
}
