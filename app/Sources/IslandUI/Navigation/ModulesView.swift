import IslandCore
import SwiftUI

struct ModulesView: View {
  let mediaEnabled: Bool
  let calendarEnabled: Bool
  let claudeAvailable: Bool
  let soonAvailable: Bool
  let onSelectView: (ExpandedView) -> Void

  var body: some View {
    HStack(spacing: 8) {
      tile("Duo", subtitle: "Музыка и события", symbol: "rectangle.split.2x1", view: .duo, enabled: mediaEnabled || calendarEnabled)
      tile("Музыка", subtitle: "Плеер", symbol: "music.note", view: .player, enabled: mediaEnabled)
      tile("Календарь", subtitle: "События и месяц", symbol: "calendar", view: .calendar, enabled: calendarEnabled)
      tile(
        "Claude Code", subtitle: claudeAvailable ? "Лимиты и прогноз" : "Нет данных", symbol: "sparkle", view: .claude,
        enabled: claudeAvailable)
      tile("Soon", subtitle: "Напоминания", symbol: "checkmark.circle", view: .soon, enabled: soonAvailable)
      ModuleTile(title: "Pomodoro", subtitle: "Скоро", symbol: "timer", enabled: false, action: {})
    }
    .padding(.horizontal, 24)
    .frame(width: ExpandedLayout.dashboard.width, height: ExpandedLayout.dashboard.height - ExpandedLayout.headerHeight)
  }

  private func tile(_ title: String, subtitle: String, symbol: String, view: ExpandedView, enabled: Bool) -> some View {
    ModuleTile(title: title, subtitle: enabled ? subtitle : (view == .claude ? subtitle : "Выключен"), symbol: symbol, enabled: enabled) {
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
        Image(systemName: symbol)
          .font(.system(size: 28, weight: .regular))
          .frame(height: 36)
          .foregroundStyle(title == "Claude Code" ? .orange : title == "Soon" ? SoonStyle.teal : IslandPalette.foreground)
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
