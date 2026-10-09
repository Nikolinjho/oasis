import Foundation
import Testing

@testable import IslandSources

actor FakeYandexLifecycle: YandexLifecycle {
  var pids: [Int32] = [10]
  var launchArguments: [[String]] = []
  var listenerPID: Int32 = 20
  var listenerAddress = "127.0.0.1:12345"
  var terminateExits = true
  var busy = false
  var holdPIDs = false
  var pendingPIDs: CheckedContinuation<[Int32], Never>?
  var capturedPIDs: [Int32] = []
  func appURL() async -> URL? { URL(fileURLWithPath: "/Applications/Yandex Music.app") }
  func runningPIDs() async -> [Int32] {
    if holdPIDs {
      holdPIDs = false
      capturedPIDs = pids
      return await withCheckedContinuation { pendingPIDs = $0 }
    }
    return pids
  }
  func holdNextPIDs() { holdPIDs = true }
  func releasePIDs() {
    pendingPIDs?.resume(returning: capturedPIDs)
    pendingPIDs = nil
  }

  func isRunning(_ pid: Int32) async -> Bool { pids.contains(pid) }
  func terminate(_ pid: Int32) async throws { if terminateExits { pids.removeAll { $0 == pid } } }
  func launch(_ app: URL, arguments: [String]) async throws -> Int32 {
    launchArguments.append(arguments)
    pids = [20]
    return 20
  }
  func freePort() async throws -> Int { 12345 }
  func listeners(port: Int) async throws -> [YandexListener] {
    if busy { return [.init(pid: 99, address: listenerAddress)] }
    return pids.contains(20) ? [.init(pid: listenerPID, address: listenerAddress)] : []
  }
  func setBusy() { busy = true }
  func setTerminateStuck() { terminateExits = false }
  func restartNormally() { pids = [30] }
  func wrongOwner() { listenerPID = 99 }
}
struct FakeYandexHTTP: YandexHTTP {
  func targets(port: Int) async throws -> Data {
    Data(
      "[{\"type\":\"page\",\"url\":\"music-application://desktop/home\",\"webSocketDebuggerUrl\":\"ws://127.0.0.1:\(port)/devtools/page/A\"}]"
        .utf8)
  }
}
struct YandexMusicClientTests {
  func client(_ lifecycle: FakeYandexLifecycle, store: MemoryYandexSessionStore = .init()) -> YandexMusicClient {
    YandexMusicClient(lifecycle: lifecycle, http: FakeYandexHTTP(), store: store, attempts: 2, interval: .milliseconds(1))
  }
  @Test("Выбор провайдера не перезапускает клиент")
  func passive() async {
    let life = FakeYandexLifecycle()
    let client = client(life)
    await #expect(throws: YandexClientError.requiresConnection) { try await client.endpoint() }
    #expect(await life.launchArguments.isEmpty)
  }
  @Test("Подключение сохраняется между экземплярами Oasis, обычный перезапуск требует согласия снова")
  func persistence() async throws {
    let life = FakeYandexLifecycle()
    let store = MemoryYandexSessionStore()
    let first = client(life, store: store)
    try await first.connect()
    #expect(try await first.endpoint().port == 12345)
    let second = client(life, store: store)
    #expect(try await second.endpoint().port == 12345)
    await life.restartNormally()
    await #expect(throws: YandexClientError.requiresConnection) { try await second.endpoint() }
    #expect(await life.launchArguments.count == 1)
  }
  @Test("Занятый порт не приводит к запуску, зависший выход не приводит к двойному клиенту")
  func unsafeLaunch() async {
    let busy = FakeYandexLifecycle()
    await busy.setBusy()
    await #expect(throws: YandexClientError.busyPort) { try await client(busy).connect() }
    #expect(await busy.launchArguments.isEmpty)
    let stuck = FakeYandexLifecycle()
    await stuck.setTerminateStuck()
    await #expect(throws: YandexClientError.terminationTimeout) { try await client(stuck).connect() }
    #expect(await stuck.launchArguments.isEmpty)
  }
  @Test("Отключение перезапускает клиент без отладочных аргументов")
  func normalRestart() async throws {
    let life = FakeYandexLifecycle()
    let client = client(life)
    try await client.connect()
    try await client.disconnect()
    #expect(await life.launchArguments.last == [])
    await #expect(throws: YandexClientError.requiresConnection) { try await client.endpoint() }
  }
  @Test("Недоступная страница не объявляет подключение успешным и оставляет возможность закрыть порт")
  func startupNotReady() async throws {
    struct EmptyHTTP: YandexHTTP { func targets(port: Int) async throws -> Data { Data("[]".utf8) } }
    let life = FakeYandexLifecycle()
    let store = MemoryYandexSessionStore()
    let client = YandexMusicClient(lifecycle: life, http: EmptyHTTP(), store: store, attempts: 2, interval: .milliseconds(1))
    await #expect(throws: YandexClientError.launchTimeout) { try await client.connect() }
    #expect(await store.load()?.pid == 20)
    try await client.disconnect()
    #expect(await life.launchArguments.last == [])
  }
  @Test("Подключение отклоняет чужого владельца listener")
  func wrongOwner() async {
    let life = FakeYandexLifecycle()
    await life.wrongOwner()
    await #expect(throws: YandexClientError.unsafeEndpoint) { try await client(life).connect() }
  }

  @Test("Отмена запуска сохраняет запись порта для явного отключения")
  func cancelledStartup() async throws {
    struct SlowHTTP: YandexHTTP {
      func targets(port: Int) async throws -> Data {
        try await Task.sleep(for: .seconds(30))
        return Data("[]".utf8)
      }
    }
    let life = FakeYandexLifecycle()
    let store = MemoryYandexSessionStore()
    let client = YandexMusicClient(lifecycle: life, http: SlowHTTP(), store: store, attempts: 2, interval: .milliseconds(1))
    let task = Task { try await client.connect() }
    for _ in 0..<100 {
      if await store.load() != nil { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(await store.load()?.pid == 20)
    try await client.disconnect()
    #expect(await store.load() == nil)
  }

  @Test("Старое чтение endpoint не удаляет сессию параллельного подключения")
  func staleEndpoint() async throws {
    let life = FakeYandexLifecycle()
    let store = MemoryYandexSessionStore()
    let client = client(life, store: store)
    await life.holdNextPIDs()
    let reading = Task { try await client.endpoint() }
    for _ in 0..<100 {
      if await life.pendingPIDs != nil { break }
      try await Task.sleep(for: .milliseconds(2))
    }
    try await client.connect()
    await life.releasePIDs()
    await #expect(throws: YandexClientError.operationInProgress) { try await reading.value }
    #expect(await store.load()?.pid == 20)
    #expect(try await client.endpoint().port == 12345)
  }

}
