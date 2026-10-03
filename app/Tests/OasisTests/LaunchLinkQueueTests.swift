import Foundation
import Testing

@testable import Oasis

@MainActor
struct LaunchLinkQueueTests {
  static func url(_ id: String) -> URL { URL(string: "oasis://debug/\(id)")! }

  @Test("Ссылки до готовности ждут и после markReady выполняются в порядке прихода")
  func queuedUntilReady() {
    var done: [URL] = []
    let queue = LaunchLinkQueue { done.append($0) }
    queue.open([Self.url("a"), Self.url("b")])
    queue.open([Self.url("c")])
    #expect(done.isEmpty)
    queue.markReady()
    #expect(done == [Self.url("a"), Self.url("b"), Self.url("c")])
  }

  @Test("После готовности ссылка выполняется сразу")
  func immediateAfterReady() {
    var done: [URL] = []
    let queue = LaunchLinkQueue { done.append($0) }
    queue.markReady()
    queue.open([Self.url("d")])
    #expect(done == [Self.url("d")])
  }

  @Test("Повторный markReady не выполняет ссылки второй раз")
  func markReadyIsIdempotent() {
    var done: [URL] = []
    let queue = LaunchLinkQueue { done.append($0) }
    queue.open([Self.url("a")])
    queue.markReady()
    queue.markReady()
    #expect(done == [Self.url("a")])
  }

  @Test("Ссылка находит действие по id, неизвестный id и чужая ссылка — без действия")
  func performsActionByID() {
    var ran: [String] = []
    let sections = [
      DebugSection(
        title: "T",
        entries: [
          .action(DebugAction(id: "x.one", title: "One", run: { ran.append("one") })),
          .action(DebugAction(id: "x.two", title: "Two", run: { ran.append("two") })),
        ])
    ]
    #expect(DebugURL.perform(Self.url("x.two"), in: sections))
    #expect(!DebugURL.perform(Self.url("x.none"), in: sections))
    #expect(!DebugURL.perform(URL(string: "oasis://settings/general")!, in: sections))
    #expect(ran == ["two"])
  }
}
