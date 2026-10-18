import IslandCore
import SwiftUI

struct ClaudeAgentsSettingsCard: View {
  @ObservedObject var module: ClaudeRequestsModule

  var body: some View {
    SettingsCard(title: "Агенты и ответы") {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(module.panel.connected ? "Claude Code подключён" : "Hooks не подключены").font(.system(size: 13))
          Text("Вопросы, разовые разрешения и несколько сессий. Лимиты подключаются отдельно.")
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        Spacer()
        if module.panel.hasConnectionRecord && !module.panel.connected {
          Button("Обновить") { module.perform(.connect) }
        }
        Button(module.panel.connected || module.panel.hasConnectionRecord ? "Отключить" : "Подключить") {
          module.perform(module.panel.connected || module.panel.hasConnectionRecord ? .disconnect : .connect)
        }
      }.padding(.vertical, 8)
      if let error = module.panel.error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
      if module.panel.hasForeignDecisionHooks {
        Text(
          "Есть другие hooks для вопросов или разрешений. Они могут обработать запрос раньше Oasis. Передача ответа и продолжение Claude показаны отдельно."
        )
        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 6)
      }
      RowDivider()
      HStack {
        Text("Размер панели").font(.system(size: 13))
        Spacer()
        Picker("Размер панели", selection: Binding(get: { module.panel.compact }, set: { module.perform(.setCompact($0)) })) {
          Text("640 × 320").tag(false)
          Text("560 × 288").tag(true)
        }.labelsHidden().pickerStyle(.menu).frame(width: 140)
      }.padding(.vertical, 6)
      Button("Открыть агентов") { module.open() }.padding(.vertical, 6)
    }.onAppear { module.refreshConnection() }
  }
}
