import IslandCore
import SwiftUI

struct CodexLimitsSettingsPage: View {
  @ObservedObject var module: CodexLimitsModule
  let preview: (IslandSound) -> Void

  var body: some View {
    CodexSettingsContent(settings: module.settings, panel: module.panel, refresh: module.refresh, preview: preview)
  }
}

private struct CodexSettingsContent: View {
  @ObservedObject var settings: LimitsSettings
  let panel: CodexLimitsPanel
  let refresh: () -> Void
  let preview: (IslandSound) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .codex)
      SettingsCard(title: nil) {
        ToggleRow(title: "Codex", info: "Лимиты подписки Codex: peek по порогам и вид в раскрытом острове", isOn: $settings.enabled)
      }
      SettingsCard(title: "Подключение лимитов") {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            Text(settings.enabled ? panel.status ?? panel.freshness : "Модуль выключен").font(.system(size: 13))
            Text("Oasis использует вход Codex CLI. Для подключения выполни codex login. Лимиты обновляются раз в минуту.")
              .font(.system(size: 11)).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 0)
          Button("Обновить", action: refresh).disabled(!settings.enabled)
        }
        .padding(.horizontal, SettingsLayout.rowInset)
        .padding(.vertical, 8)
      }
      LimitsSettingsCards(settings: settings, preview: preview)
    }
  }
}
