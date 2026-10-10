import IslandCore
import SwiftUI

struct SoonListView: View {
  let panel: SoonPanel
  let now: Date
  let onAction: (SoonAction) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("Soon")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(IslandPalette.foreground)
        Spacer()
        Button("Добавить") { onAction(.create) }
      }
      .frame(height: 18)
      ScrollView {
        LazyVStack(spacing: 0) {
          if panel.visibleReminders.isEmpty {
            Text(panel.showsCompleted ? "Завершённых напоминаний нет" : "Напоминаний пока нет")
              .font(.system(size: 12))
              .foregroundStyle(IslandPalette.secondary)
              .frame(maxWidth: .infinity, minHeight: 84, alignment: .center)
          } else {
            ForEach(panel.visibleReminders) { reminder in
              SoonListRow(reminder: reminder, now: now, onAction: onAction)
            }
          }
        }
      }
      .scrollIndicators(.hidden)
      .frame(height: 84)
      HStack {
        Button(panel.showsCompleted ? "Активные" : "Завершённые") {
          onAction(panel.showsCompleted ? .showList : .showCompleted)
        }
        Spacer()
        if panel.showsCompleted, panel.reminders.contains(where: { $0.state == .completed }) {
          Button("Очистить") { onAction(.clearCompleted) }
        }
      }
      .font(.system(size: 10))
      .foregroundStyle(IslandPalette.secondary)
      .frame(height: 11)
    }
    .font(.system(size: 12))
    .buttonStyle(SoonTextButtonStyle())
    .padding(.horizontal, 24)
    .padding(.top, 32)
    .padding(.bottom, 22)
    .frame(width: 345, height: 175, alignment: .top)
  }
}

private struct SoonListRow: View {
  let reminder: SoonReminder
  let now: Date
  let onAction: (SoonAction) -> Void
  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 6) {
      Button {
        onAction(.open(id: reminder.id, revision: reminder.revision))
      } label: {
        HStack(spacing: 6) {
          Text(reminder.title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(IslandPalette.foreground)
            .underline(isHovered)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(reminder.title)
          Text(SoonStyle.remaining(reminder, now: now))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(IslandPalette.secondary)
            .lineLimit(1)
            .fixedSize()
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .onHover { isHovered = $0 }
      .help(reminder.title)
      Button(reminder.state == .completed ? "Повторить" : "Готово") {
        onAction(
          reminder.state == .completed
            ? .repeatReminder(id: reminder.id, revision: reminder.revision)
            : .complete(id: reminder.id, revision: reminder.revision))
      }
      .font(.system(size: 11))
      .fixedSize()
    }
    .frame(height: 28)
  }
}

internal enum SoonStyle {
  static let teal = Color(ActivityLayouts.soonTeal)

  static func remaining(_ reminder: SoonReminder, now: Date) -> String {
    if reminder.state == .completed { return "Готово" }
    let seconds = max(0, Int(reminder.dueAt.timeIntervalSince(now).rounded(.up)))
    if reminder.state == .due || seconds == 0 { return "Пора" }
    if seconds < 3_600 { return String(format: "%d:%02d", seconds / 60, seconds % 60) }
    return String(format: "%d:%02d:%02d", seconds / 3_600, (seconds % 3_600) / 60, seconds % 60)
  }
}
