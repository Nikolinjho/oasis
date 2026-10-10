import IslandCore
import SwiftUI

struct SoonDetailView: View {
  let reminder: SoonReminder
  let now: Date
  let onAction: (SoonAction) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Button("Назад") { onAction(.showList) }
          .foregroundStyle(IslandPalette.secondary)
        Spacer()
        Text("Soon")
          .foregroundStyle(SoonStyle.teal)
      }
      .frame(height: 16)
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          Text(reminder.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(IslandPalette.foreground)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(reminder.title)
            .textSelection(.enabled)
          HStack(spacing: 8) {
            Text(SoonStyle.remaining(reminder, now: now))
              .font(.system(size: 13, weight: .medium, design: .monospaced))
              .foregroundStyle(SoonStyle.teal)
            Text(reminder.dueAt, format: .dateTime.hour().minute())
              .foregroundStyle(IslandPalette.secondary)
            Text(stateLabel)
              .foregroundStyle(IslandPalette.secondary)
          }
          .font(.system(size: 11))
          if reminder.state == .completed {
            Button("Повторить") { onAction(.repeatReminder(id: reminder.id, revision: reminder.revision)) }
              .foregroundStyle(SoonStyle.teal)
          } else {
            HStack(spacing: 14) {
              Button("Готово") { onAction(.complete(id: reminder.id, revision: reminder.revision)) }
                .foregroundStyle(SoonStyle.teal)
              Button("+5 мин") { onAction(.snooze(id: reminder.id, revision: reminder.revision, seconds: 300)) }
              Button("Отложить…") { onAction(.customSnooze(id: reminder.id, revision: reminder.revision)) }
            }
          }
          HStack(spacing: 14) {
            if reminder.state != .completed {
              Button("Изменить") { onAction(.edit(id: reminder.id, revision: reminder.revision)) }
            }
            Button("Удалить") { onAction(.delete(id: reminder.id, revision: reminder.revision)) }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
    }
    .font(.system(size: 12))
    .foregroundStyle(IslandPalette.foreground)
    .buttonStyle(.plain)
    .padding(.horizontal, 24)
    .padding(.top, 32)
    .padding(.bottom, 22)
    .frame(width: 345, height: 175, alignment: .top)
  }

  private var stateLabel: String {
    if reminder.state == .completed { return "Завершено" }
    return reminder.state == .due || reminder.dueAt <= now ? "Пора" : "Запланировано"
  }
}
