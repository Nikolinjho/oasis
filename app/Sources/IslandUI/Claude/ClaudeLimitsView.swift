import IslandCore
import SwiftUI

/// Вид Claude Code 345×175: шапка, карточки 5ч и 7д, строка прогноза (макет спеки модуля).
/// Размеры шрифтов и отступов не мерили: по макету и в тон плеера
struct ClaudeLimitsView: View {
  let panel: ClaudePanel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        ActivityIcon(layout: ActivityLayouts.claudeIcon)
        Text("Claude Code")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(IslandPalette.foreground)
        Spacer(minLength: 8)
        Text(panel.freshness)
          .font(.system(size: 11))
          .foregroundStyle(IslandPalette.secondary)
      }
      HStack(spacing: 10) {
        LimitCard(title: "5 часов", window: panel.limits.fiveHour, panel: panel, weekday: false)
        LimitCard(title: "7 дней", window: panel.limits.sevenDay, panel: panel, weekday: true)
      }
      if let forecast = panel.forecastText {
        Text(forecast)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(IslandPalette.foreground)
          .lineLimit(2)
          .minimumScaleFactor(0.85)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .frame(width: DuoLayout.size.width, height: DuoLayout.size.height, alignment: .top)
  }
}

/// Карточка окна: остаток крупно, полоска в цвете уровня, время сброса. Нет окна — пустая карточка
struct LimitCard: View {
  let title: String
  let window: ClaudeWindow?
  let panel: ClaudePanel
  let weekday: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 11))
        .foregroundStyle(IslandPalette.secondary)
      if let window {
        let remaining = panel.remaining(window)
        let color = Color(ActivityLayouts.limitColor(remaining: remaining))
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text("\(remaining)%")
            .font(.system(size: 22, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(IslandPalette.foreground)
          Text(panel.now >= window.resetsAt ? "расчёт" : "осталось")
            .font(.system(size: 11))
            .foregroundStyle(IslandPalette.secondary)
        }
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(IslandPalette.placeholder)
            Capsule().fill(color).frame(width: proxy.size.width * Double(remaining) / 100)
          }
        }
        .frame(height: 4)
        Text(panel.resetText(window, weekday: weekday))
          .font(.system(size: 10))
          .foregroundStyle(IslandPalette.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      } else {
        Text("нет данных")
          .font(.system(size: 11))
          .foregroundStyle(IslandPalette.secondary)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(IslandPalette.placeholder, lineWidth: 1))
  }
}
