import IslandCore
import SwiftUI

struct CodexSettingsPage: View {
  @ObservedObject var module: CodexRequestsModule

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .codex)
      SettingsCard(title: "Агенты и ответы") {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text(module.connectionTitle).font(.system(size: 13))
            Text("Общих сессий: \(module.sessionCount)").font(.system(size: 11)).foregroundStyle(.secondary)
          }
          Spacer()
          Button(module.enabled ? "Отключить" : "Подключить") { module.setEnabled(!module.enabled) }
        }.padding(.vertical, 8)
        Text(
          "Oasis видит сессии общего сервера Codex. Если сессия не появилась, запусти codex --remote unix://. Уже открытые автономные сессии сюда не подключаются."
        )
        .font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled).padding(.bottom, 6)
        if let error = module.panel.error { Text(error).font(.system(size: 11)).foregroundStyle(.secondary) }
        RowDivider()
        HStack {
          Text("Размер панели").font(.system(size: 13))
          Spacer()
          Picker("Размер панели", selection: Binding(get: { module.panel.compact }, set: { module.perform(.setCompact($0)) })) {
            Text("640 × 320").tag(false)
            Text("560 × 288").tag(true)
          }.labelsHidden().pickerStyle(.menu).frame(width: 140)
        }.padding(.vertical, 6)
        Button("Открыть агентов Codex") { module.open() }.padding(.vertical, 6)
      }
      SettingsCard(title: "Один опросник в двух окнах") {
        Text(
          "Первый принятый сервером ответ завершает ожидание в терминале и Oasis. Черновики независимые. Закрытие Oasis оставляет терминал работоспособным."
        )
        .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 8)
        Text(
          "После разрыва подключения старые формы недоступны, черновики удаляются. При восстановлении появятся только запросы, которые сервер ещё ожидает."
        )
        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 8)
      }
    }
  }
}
