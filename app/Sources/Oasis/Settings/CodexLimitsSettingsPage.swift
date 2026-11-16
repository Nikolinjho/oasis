import IslandUI
import SwiftUI

struct CodexLimitsSettingsPage: View {
  @ObservedObject var module: CodexLimitsModule

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .codex)
      SettingsCard(title: nil) {
        ToggleRow(title: "Лимиты Codex", isOn: $module.enabled)
      }
      if module.enabled {
        SettingsCard(title: "Подключение лимитов") {
          VStack(alignment: .leading, spacing: 10) {
            Text(module.panel.status ?? module.panel.freshness)
            Text("Oasis использует вход установленного Codex CLI. Для подключения выполни codex login. Лимиты обновляются раз в минуту.")
              .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("Обновить", action: module.refresh)
          }
          .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}
