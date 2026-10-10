import Foundation
import IslandCore
import IslandSources
import os

/// Каждая демонстрация получает свой JSON. Живые напоминания и системные запросы не меняются.
@MainActor
enum DebugSoon {
  static func section(_ module: SoonModule) -> DebugSection {
    DebugSection(
      title: "Soon",
      entries: [
        action("empty", "Empty", module: module),
        action("list", "Six reminders + completed", module: module),
        action("due", "Two due reminders", module: module),
        action("catchup", "Catch up after sleep", module: module),
        .action(
          DebugAction(id: "soon.composer", title: "Composer (isolated)") {
            prepare("empty", module: module, composer: true)
          }),
        .action(
          DebugAction(id: "soon.live", title: "Use real reminders") {
            module.useDebugRepository(nil)
            module.perform(.showList)
          }),
      ])
  }

  private static func action(_ id: String, _ title: String, module: SoonModule) -> DebugEntry {
    .action(DebugAction(id: "soon." + id, title: title) { prepare(id, module: module) })
  }

  private static func prepare(_ scenario: String, module: SoonModule, composer: Bool = false) {
    Task {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("oasis-soon-debug", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
      let repository = SoonRepository(url: directory.appendingPathComponent("reminders-v1.json"))
      do {
        if scenario == "list" { try await seedList(repository) }
        if scenario == "due" || scenario == "catchup" {
          for title in ["Ответить Саше", "Выключить плиту"] {
            _ = try await repository.add(title: title, durationSeconds: 30, now: Date().addingTimeInterval(-60))
          }
        }
        module.useDebugRepository(repository, catchUp: scenario != "due")
        module.perform(composer ? .create : .showList)
      } catch {
        Logger(subsystem: "dev.nikoko.oasis", category: "soon").error("debug store: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private static func seedList(_ repository: SoonRepository) async throws {
    let titles = [
      "Ответить Саше", "Проверить сборку", "Забрать доставку",
      "Напоминание с очень длинным названием, которое целиком доступно в деталях", "Выпить воды", "Вернуться к задаче",
    ]
    for (index, title) in titles.enumerated() {
      _ = try await repository.add(title: title, durationSeconds: 300 + index * 600, now: Date())
    }
    let completed = try await repository.add(title: "Отправить письмо", durationSeconds: 300, now: Date())
    _ = try await repository.complete(id: completed.id, revision: completed.revision)
  }
}
