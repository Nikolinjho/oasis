import IslandCore
import SwiftUI

/// Claude Code: модуль лимитов подписки (спека модуля, раздел «Настройки»). Зависимые строки скрываются, как у Alcove
struct ClaudeSettingsPage: View {
  @ObservedObject var settings: LimitsSettings
  @ObservedObject var connection: ClaudeConnection
  let preview: (IslandSound) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .claudeCode)
      SettingsCard(title: nil) {
        ToggleRow(title: "Claude Code", info: "Лимиты подписки Claude: peek по порогам и вид в раскрытом острове", isOn: $settings.enabled)
      }
      SettingsCard(title: "Подключение лимитов") {
        ConnectionRow(connection: connection, text: settings.statuslineText)
        RowDivider()
        LimitsChoiceRow(
          title: "Строка статуса Claude Code", selection: $settings.statuslineText,
          options: [(value: true, title: "5h 91%"), (value: false, title: "Ничего")])
      }
      LimitsSettingsCards(settings: settings, preview: preview)
    }
  }
}

/// Подключение statusline с выбором сохранения или замены прежней команды
struct ConnectionRow: View {
  @ObservedObject var connection: ClaudeConnection
  let text: Bool
  @State private var confirmsReplacement = false

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 13))
        if let detail {
          Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer()
      if connection.status == .installed || connection.hasConnectionRecord {
        Button("Отключить") { connection.disconnect() }
      } else {
        Button("Подключить") {
          if case .foreign = connection.status { confirmsReplacement = true } else { connection.connect(text: text) }
        }
        .disabled(isInvalid)
      }
    }
    .padding(.horizontal, SettingsLayout.rowInset)
    .padding(.vertical, 8)
    .onAppear { connection.refresh() }
    .confirmationDialog("Подключить Oasis к строке статуса Claude Code?", isPresented: $confirmsReplacement) {
      Button("Сохранить прежнюю строку") { connection.connect(text: text) }
      Button("Заменить прежнюю строку") { connection.connect(text: text, preservePrevious: false) }
      Button("Отмена", role: .cancel) {}
    } message: {
      Text(
        "Сохранение запускает прежнюю строку вместе с Oasis. Замена оставляет только Oasis. При отключении прежняя строка восстановится.")
    }
  }

  private var isInvalid: Bool {
    if case .invalid = connection.status { return true }
    return false
  }

  private var title: String {
    connection.status == .installed ? "Подключено" : "Statusline не подключён"
  }

  private var detail: String? {
    if let error = connection.error { return error }
    if connection.hasConnectionRecord, connection.status != .installed {
      return "Прежнее подключение изменено. Сначала отключите его, затем подключите снова."
    }
    if case .invalid(let message) = connection.status { return message }
    if case .foreign = connection.status { return "Прежняя строка настроена. При подключении можно сохранить её или заменить" }
    return nil
  }
}
