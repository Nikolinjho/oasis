import IslandCore
import SwiftUI

/// Claude Code: модуль лимитов подписки (спека модуля, раздел «Настройки»). Зависимые строки скрываются, как у Alcove
struct ClaudeSettingsPage: View {
  @ObservedObject var settings: ClaudeSettings
  @ObservedObject var connection: ClaudeConnection
  var agents: ClaudeRequestsModule?
  let preview: (IslandSound) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .claudeCode)
      SettingsCard(title: nil) {
        ToggleRow(title: "Claude Code", info: "Лимиты подписки Claude: peek по порогам и вид в раскрытом острове", isOn: $settings.enabled)
      }
      if let agents { ClaudeAgentsSettingsCard(module: agents) }
      SettingsCard(title: "Подключение лимитов") {
        ConnectionRow(connection: connection, text: settings.statuslineText)
        RowDivider()
        ClaudeChoiceRow(
          title: "Строка статуса Claude Code", selection: $settings.statuslineText,
          options: [(value: true, title: "5h 91%"), (value: false, title: "Ничего")])
      }
      if settings.enabled {
        SettingsCard(title: "Предупреждения") {
          ToggleRow(
            title: "Предупреждение о лимите сессии", info: "Peek, когда остаток 5-часового окна падает ниже порога",
            isOn: $settings.sessionWarning)
          if settings.sessionWarning {
            RowDivider()
            ThresholdRow(selection: $settings.thresholds)
            RowDivider()
            HStack(spacing: 6) {
              ToggleRow(title: "Звук на 5% и 0%", isOn: $settings.criticalSound)
              Button {
                preview(.lowBattery)
              } label: {
                Image(systemName: "play.circle.fill").font(.system(size: 13))
              }
              .buttonStyle(.plain)
            }
          }
          RowDivider()
          ToggleRow(title: "Сброс окна", info: "Peek, когда лимит снова 100%", isOn: $settings.resetNotice)
        }
        SettingsCard(title: "Раскрытый остров") {
          ToggleRow(title: "Вид в раскрытом острове", isOn: $settings.expandedView)
          if settings.expandedView {
            RowDivider()
            ClaudeChoiceRow(
              title: "Прогноз дня до", selection: $settings.forecastUntilWorkday,
              options: [(value: false, title: "Полночь"), (value: true, title: "Конец рабочего дня")])
            if settings.forecastUntilWorkday {
              RowDivider()
              WorkdayEndRow(minutes: $settings.workdayEnd)
            }
          }
        }
      }
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

/// Пороги 50, 25, 10, 5: плитки, можно выбрать несколько
struct ThresholdRow: View {
  @Binding var selection: [Int]
  static let options = [50, 25, 10, 5]

  var body: some View {
    HStack {
      Text("Пороги").font(.system(size: 13))
      Spacer()
      ForEach(Self.options, id: \.self) { value in
        let isOn = selection.contains(value)
        Button {
          toggle(value)
        } label: {
          Text("\(value)%")
            .font(.system(size: 12, weight: .medium))
            .frame(width: 44, height: 24)
            .background(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isOn ? SettingsPalette.accent : Color.primary.opacity(0.08))
            )
            .foregroundStyle(isOn ? .white : .primary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 6)
  }

  private func toggle(_ value: Int) {
    let updated = selection.contains(value) ? selection.filter { $0 != value } : selection + [value]
    selection = updated.sorted(by: >)
  }
}

/// Конец рабочего дня: слайдер 16:00…23:00 с шагом 30 минут, значение — «20:00»
struct WorkdayEndRow: View {
  @Binding var minutes: Int

  var body: some View {
    HStack {
      Text("Конец рабочего дня").font(.system(size: 13))
      Spacer()
      Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }), in: 960...1380, step: 30)
        .frame(width: 160)
        .tint(SettingsPalette.accent)
      Text(String(format: "%02d:%02d", minutes / 60, minutes % 60))
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .frame(width: 44)
    }
    .padding(.vertical, 6)
  }
}

/// Компактный выбор для двух настроек модуля.
private struct ClaudeChoiceRow: View {
  let title: String
  @Binding var selection: Bool
  let options: [(value: Bool, title: String)]

  var body: some View {
    HStack {
      Text(title).font(.system(size: 13))
      Spacer()
      Picker(title, selection: $selection) {
        ForEach(options, id: \.value) { option in
          Text(option.title).tag(option.value)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .fixedSize()
    }
    .padding(.vertical, 8)
  }
}
