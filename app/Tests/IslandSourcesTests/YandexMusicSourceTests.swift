import Foundation
import IslandCore
import Testing

@testable import IslandSources

struct FakeYandexClient: YandexClient {
  let value: URL
  func endpoint() async throws -> URL { value }
  func connect() async throws {}
  func disconnect() async throws {}
}
actor ClosingYandexClient: YandexClient {
  var closed = false
  func endpoint() async throws -> URL {
    if closed { throw YandexClientError.appClosed }
    return URL(string: "ws://127.0.0.1:123/devtools/page/A")!
  }
  func connect() async throws {}
  func disconnect() async throws {}
  func closeApp() { closed = true }
}
actor FakeYandexConnection: CDPConnection {
  nonisolated let events: AsyncStream<CDPEvent>
  let continuation: AsyncStream<CDPEvent>.Continuation
  var track = "A"
  var closed = false
  var commands = 0
  var evaluations: [String] = []
  var holdNext = false
  var pendingCommand: CheckedContinuation<JSONValue, any Error>?
  var nextCommandOK = true
  var holdDisposal = false
  var pendingDisposal: CheckedContinuation<JSONValue, any Error>?
  init() { (events, continuation) = AsyncStream.makeStream() }
  func setTrack(_ value: String) { track = value }
  func request(_ method: String, params: JSONValue) async throws -> JSONValue {
    if closed { throw CDPError.disconnected }
    guard method == "Runtime.evaluate" else { return .object([:]) }
    let expression = params["expression"].string ?? ""
    evaluations.append(expression)
    if expression.contains("?.dispose()"), holdDisposal {
      holdDisposal = false
      return try await withCheckedThrowingContinuation { pendingDisposal = $0 }
    }
    if expression.contains(".command(") {
      commands += 1
      if holdNext {
        holdNext = false
        return try await withCheckedThrowingContinuation { pendingCommand = $0 }
      }
      let ok = nextCommandOK
      nextCommandOK = true
      return commandResult(ok)

    }
    return .object(["result": .object(["value": snapshot()])])
  }
  func snapshot() -> JSONValue {
    .object([
      "version": .number(1), "state": .string("ready"), "sampledAt": .number(Date().timeIntervalSince1970), "trackID": .string(track),
      "title": .string(track), "isPlaying": .bool(false), "duration": .number(200), "position": .number(0),
      "artworkURL": .string("https://art.test/\(track)"), "shuffleMode": .number(1), "repeatMode": .number(1),
      "capabilities": .object([
        "canPlayPause": .bool(true), "canNext": .bool(true), "canPrevious": .bool(true), "canSeek": .bool(true),
        "canFavorite": .bool(false), "shuffleModes": .array([.number(1), .number(3)]),
        "repeatModes": .array([.number(1), .number(3), .number(2)]),
      ]),
    ])
  }
  func commandResult(_ ok: Bool) -> JSONValue {
    .object(["result": .object(["value": .object(["ok": .bool(ok), "snapshot": snapshot(), "error": .string("notConfirmed")])])])
  }
  func holdCommand() { holdNext = true }
  func holdCleanup() { holdDisposal = true }
  func releaseCleanup() {
    pendingDisposal?.resume(returning: .object([:]))
    pendingDisposal = nil
  }
  func failNextCommand() { nextCommandOK = false }
  func finishCommand(_ ok: Bool) {
    pendingCommand?.resume(returning: commandResult(ok))
    pendingCommand = nil
  }
  func binding(track id: String, sampledAt: Double) {
    var data: [String: JSONValue] = [:]
    if case .object(let values) = snapshot() { data = values }
    data["trackID"] = .string(id)
    data["title"] = .string(id)
    data["sampledAt"] = .number(sampledAt)
    continuation.yield(
      CDPEvent(
        method: "Runtime.bindingCalled",
        params: .object(["name": .string("oasisYandexChanged"), "payload": .string(JSONValue.object(data).json)])))
  }
  func emit(_ method: String, params: JSONValue = .object([:])) { continuation.yield(CDPEvent(method: method, params: params)) }
  func close() async {
    closed = true
    releaseCleanup()
    continuation.finish()
  }
}
actor DeferredYandexArtwork {
  var requests: [String: CheckedContinuation<Data?, Never>] = [:]
  func load(_ url: URL) async -> Data? { await withCheckedContinuation { requests[url.lastPathComponent] = $0 } }
  func ready(_ id: String) async -> Bool { requests[id] != nil }
  func finish(_ id: String) { requests.removeValue(forKey: id)?.resume(returning: Data(id.utf8)) }
}
actor YandexChangeCollector {
  var values: [NowPlayingChange] = []
  func append(_ value: NowPlayingChange) { values.append(value) }
  func has(_ title: String) -> Bool {
    values.contains {
      switch $0 {
      case .newTrack(let info), .updated(let info): info.title == title
      case .cleared: false
      }
    }
  }
}
actor YandexStatusCollector {
  var values: [NowPlayingSourceState] = []
  func append(_ value: NowPlayingSourceState) { values.append(value) }
  func hasFailure() -> Bool {
    values.contains {
      if case .commandFailed = $0 { return true }
      return false
    }
  }
}
struct YandexMusicSourceTests {
  @Test("Поздняя обложка старого трека не обновляет новый, stop закрывает сокет")
  func lateArtwork() async throws {
    let connection = FakeYandexConnection()
    let artwork = DeferredYandexArtwork()
    let collector = YandexChangeCollector()
    let source = YandexMusicSource(
      script: "bridge", client: FakeYandexClient(value: URL(string: "ws://127.0.0.1:123/devtools/page/A")!),
      connection: { _ in connection }, artwork: { await artwork.load($0) }, pollInterval: .milliseconds(10))
    let reader = Task { for await change in source.changes { await collector.append(change) } }
    source.start()
    for _ in 0..<100 {
      if await artwork.ready("A") { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    #expect(await collector.has("A"))
    await connection.setTrack("B")
    for _ in 0..<100 {
      if await artwork.ready("B") { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    await artwork.finish("A")
    await artwork.finish("B")
    try await Task.sleep(for: .milliseconds(20))
    let values = await collector.values
    #expect(
      values.contains {
        if case .updated(let info) = $0 { return info.title == "B" && info.artwork == Data("B".utf8) }
        return false
      })
    #expect(
      !values.contains {
        if case .updated(let info) = $0 { return info.title == "B" && info.artwork == Data("A".utf8) }
        return false
      })
    source.stop()
    try await Task.sleep(for: .milliseconds(20))
    #expect(await connection.closed)
    reader.cancel()
  }
  @Test("Две быстрые команды next выполняются обе, поздний binding не возвращает старый трек")
  func commandsAndStaleSnapshot() async throws {
    let connection = FakeYandexConnection()
    let collector = YandexChangeCollector()
    let source = YandexMusicSource(
      script: "bridge", client: FakeYandexClient(value: URL(string: "ws://127.0.0.1:123/devtools/page/A")!),
      connection: { _ in connection }, artwork: { _ in nil }, pollInterval: .seconds(10))
    let reader = Task { for await change in source.changes { await collector.append(change) } }
    source.start()
    for _ in 0..<100 {
      if await collector.has("A") { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    source.send(.nextTrack)
    source.send(.nextTrack)
    for _ in 0..<100 {
      if await connection.commands == 2 { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    #expect(await connection.commands == 2)
    await connection.binding(track: "OLD", sampledAt: 0)
    try await Task.sleep(for: .milliseconds(20))
    #expect(!(await collector.has("OLD")))
    source.stop()
    reader.cancel()
  }
  @Test("Навигация iframe и короткая загрузка не создают повторный newTrack")
  func contextLoss() async throws {
    let connection = FakeYandexConnection()
    let collector = YandexChangeCollector()
    let source = YandexMusicSource(
      script: "bridge", client: FakeYandexClient(value: URL(string: "ws://127.0.0.1:123/devtools/page/A")!),
      connection: { _ in connection }, artwork: { _ in nil }, pollInterval: .milliseconds(20))
    let reader = Task { for await change in source.changes { await collector.append(change) } }
    source.start()
    for _ in 0..<100 {
      if await collector.has("A") { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    await connection.emit(
      "Page.frameNavigated", params: .object(["frame": .object(["id": .string("child"), "parentId": .string("main")])]))
    await connection.emit("Runtime.executionContextsCleared")
    try await Task.sleep(for: .milliseconds(60))
    let values = await collector.values
    #expect(
      values.filter {
        if case .newTrack = $0 { return true }
        return false
      }.count == 1)
    #expect(
      !values.contains {
        if case .cleared = $0 { return true }
        return false
      })
    source.stop()
    reader.cancel()
  }

  @Test("Старый отказ команды не сбрасывает новую, успешная команда явно сообщает connected")
  func commandFailures() async throws {
    let connection = FakeYandexConnection()
    let collector = YandexStatusCollector()
    let source = YandexMusicSource(
      script: "bridge", client: FakeYandexClient(value: URL(string: "ws://127.0.0.1:123/devtools/page/A")!),
      connection: { _ in connection }, artwork: { _ in nil }, pollInterval: .seconds(10))
    let reader = Task { for await state in source.statuses { await collector.append(state) } }
    source.start()
    try await eventually { await collector.values.contains(.connected) }
    await connection.holdCommand()
    source.setShuffle(3)
    try await eventually { await connection.commands == 1 }
    source.setShuffle(1)
    await connection.finishCommand(false)
    try await eventually { await connection.commands == 2 }
    #expect(!(await collector.hasFailure()))
    await connection.failNextCommand()
    source.setRepeat(3)
    try await eventually { await collector.hasFailure() }
    #expect(await collector.hasFailure())
    source.setRepeat(1)
    try await eventually { await connection.commands == 4 }
    try await Task.sleep(for: .milliseconds(10))
    #expect(await collector.values.last == .connected)
    source.stop()
    reader.cancel()
  }

  @Test("Новый экземпляр источника ждёт dispose старого перед внедрением bridge")
  func crossInstanceCleanup() async throws {
    let old = FakeYandexConnection()
    let fresh = FakeYandexConnection()
    let oldCollector = YandexChangeCollector()
    let freshCollector = YandexChangeCollector()
    let client = FakeYandexClient(value: URL(string: "ws://127.0.0.1:123/devtools/page/A")!)
    let first = YandexMusicSource(
      script: "bridge", client: client, connection: { _ in old }, artwork: { _ in nil }, pollInterval: .seconds(10))
    let second = YandexMusicSource(
      script: "bridge", client: client, connection: { _ in fresh }, artwork: { _ in nil }, pollInterval: .seconds(10))
    let firstReader = Task { for await value in first.changes { await oldCollector.append(value) } }
    let secondReader = Task { for await value in second.changes { await freshCollector.append(value) } }
    first.start()
    try await eventually { await oldCollector.has("A") }
    await old.holdCleanup()
    first.stop()
    second.start()
    try await eventually { await old.pendingDisposal != nil }
    try await Task.sleep(for: .milliseconds(20))
    #expect(await fresh.evaluations.isEmpty)
    await old.releaseCleanup()
    try await eventually { await freshCollector.has("A") }
    #expect(await old.closed)
    second.stop()
    firstReader.cancel()
    secondReader.cancel()
  }

  @Test("Stop ждёт очистку, уже начатую фоновым polling, перед новым экземпляром")
  func backgroundCleanup() async throws {
    let old = FakeYandexConnection()
    let fresh = FakeYandexConnection()
    let client = ClosingYandexClient()
    let collector = YandexChangeCollector()
    let first = YandexMusicSource(
      script: "bridge", client: client, connection: { _ in old }, artwork: { _ in nil }, pollInterval: .milliseconds(10))
    let second = YandexMusicSource(
      script: "bridge", client: FakeYandexClient(value: URL(string: "ws://127.0.0.1:123/devtools/page/A")!), connection: { _ in fresh },
      artwork: { _ in nil }, pollInterval: .seconds(10))
    let reader = Task { for await value in first.changes { await collector.append(value) } }
    first.start()
    try await eventually { await collector.has("A") }
    await old.holdCleanup()
    await client.closeApp()
    try await eventually { await old.pendingDisposal != nil }
    first.stop()
    second.start()
    try await Task.sleep(for: .milliseconds(20))
    #expect(await fresh.evaluations.isEmpty)
    await old.releaseCleanup()
    try await eventually { await fresh.evaluations.contains("bridge") }
    #expect(await old.closed)
    second.stop()
    reader.cancel()
  }

  private func eventually(_ condition: @Sendable () async -> Bool) async throws {
    for _ in 0..<100 {
      if await condition() { return }
      try await Task.sleep(for: .milliseconds(2))
    }
    Issue.record("Условие не выполнилось за время ожидания")
  }

}
