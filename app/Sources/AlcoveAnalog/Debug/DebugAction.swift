import Foundation
import os

/// Синтетическое действие для отладки: шлёт в store то же событие, что и живой источник.
/// id стабильный: по нему действие вызывается из меню и по ссылке alcove-analog://debug/<id>
struct DebugAction {
  let id: String
  let title: String
  /// Галочка в меню: для переключателей режима
  var isOn: (@MainActor () -> Bool)? = nil
  let run: @MainActor () -> Void

  /// Запуск из меню или по ссылке: с записью в лог, по ней скрипты записи сверяют время шагов
  @MainActor
  func perform() {
    DebugAction.log.info("debug \(id, privacy: .public)")
    run()
  }

  static let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "debug")
}

enum DebugEntry {
  case action(DebugAction)
  case separator
}

/// Раздел меню Debug: Music, HUD, Island…
struct DebugSection {
  let title: String
  let entries: [DebugEntry]

  var actions: [DebugAction] {
    entries.compactMap { entry in
      guard case .action(let action) = entry else { return nil }
      return action
    }
  }
}

/// Ссылка alcove-analog://debug/<id>: агенты и скрипты записи вызывают действия без меню
enum DebugURL {
  static let scheme = "alcove-analog"

  static func actionID(from url: URL) -> String? {
    guard url.scheme?.lowercased() == scheme, url.host()?.lowercased() == "debug" else { return nil }
    let id = url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return id.isEmpty ? nil : id
  }
}
