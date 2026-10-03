import Foundation

/// Ссылки oasis://, пришедшие до готовности острова. При холодном запуске AppKit отдаёт их раньше
/// applicationDidFinishLaunching: действие успевало выполниться до окна и источников, а первая загрузка
/// календаря потом затирала фейковое событие. До markReady ссылки копятся, после — выполняются сразу
@MainActor
final class LaunchLinkQueue {
  private let perform: (URL) -> Void
  private var pending: [URL] = []
  private(set) var isReady = false

  init(perform: @escaping (URL) -> Void) {
    self.perform = perform
  }

  func open(_ urls: [URL]) {
    guard isReady else {
      pending.append(contentsOf: urls)
      return
    }
    urls.forEach(perform)
  }

  /// Остров и источники готовы: накопленные ссылки — по порядку прихода. Повторный вызов ничего не делает
  func markReady() {
    guard !isReady else { return }
    isReady = true
    let urls = pending
    pending = []
    urls.forEach(perform)
  }
}

extension DebugURL {
  /// oasis://debug/<id>: то же действие, что пункт меню Debug. false — ссылка чужая или id неизвестен (в логе)
  @MainActor
  @discardableResult
  static func perform(_ url: URL, in sections: [DebugSection]) -> Bool {
    guard let id = actionID(from: url) else {
      DebugAction.log.error("unknown url \(url.absoluteString, privacy: .public)")
      return false
    }
    guard let action = sections.lazy.flatMap(\.actions).first(where: { $0.id == id }) else {
      DebugAction.log.error("unknown id \(id, privacy: .public)")
      return false
    }
    action.perform()
    return true
  }
}
