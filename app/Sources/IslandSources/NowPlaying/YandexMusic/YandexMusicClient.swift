import Foundation

public protocol YandexClient: Sendable {
  func endpoint() async throws -> URL
  func connect() async throws
  func disconnect() async throws
}
public enum YandexClientError: Error, Equatable, Sendable {
  case appNotFound, appClosed, requiresConnection, notReady, busyPort, unsafeEndpoint
  case terminationTimeout, launchTimeout, operationInProgress
}
public struct YandexDebugSession: Codable, Sendable {
  public var pid: Int32
  public var port: Int
  public init(pid: Int32, port: Int) {
    self.pid = pid
    self.port = port
  }
}
public protocol YandexSessionStore: Sendable {
  func load() async -> YandexDebugSession?
  func save(_ session: YandexDebugSession?) async
}
public actor MemoryYandexSessionStore: YandexSessionStore {
  private var session: YandexDebugSession?
  public init() {}
  public func load() -> YandexDebugSession? { session }
  public func save(_ session: YandexDebugSession?) { self.session = session }
}
public actor DefaultsYandexSessionStore: YandexSessionStore {
  private let defaults = UserDefaults.standard
  private let key = "yandexMusicDebugSession"
  public init() {}
  public func load() -> YandexDebugSession? {
    defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(YandexDebugSession.self, from: $0) }
  }
  public func save(_ session: YandexDebugSession?) {
    if let session { defaults.set(try? JSONEncoder().encode(session), forKey: key) } else { defaults.removeObject(forKey: key) }
  }
}
public protocol YandexLifecycle: Sendable {
  func appURL() async -> URL?
  func runningPIDs() async -> [Int32]
  func isRunning(_ pid: Int32) async -> Bool
  func terminate(_ pid: Int32) async throws
  func launch(_ app: URL, arguments: [String]) async throws -> Int32
  func freePort() async throws -> Int
  func listeners(port: Int) async throws -> [YandexListener]
}

public actor YandexMusicClient: YandexClient {
  public static let bundleID = "ru.yandex.desktop.music"
  public static let shared = YandexMusicClient()
  private let lifecycle: any YandexLifecycle
  private let http: any YandexHTTP
  private let store: any YandexSessionStore
  private let attempts: Int
  private let interval: Duration
  private var changing = false
  private var operationRevision = 0

  public init(
    lifecycle: any YandexLifecycle = SystemYandexLifecycle(), http: any YandexHTTP = YandexLoopbackHTTP(),
    store: any YandexSessionStore = DefaultsYandexSessionStore(), attempts: Int = 80, interval: Duration = .milliseconds(100)
  ) {
    self.lifecycle = lifecycle
    self.http = http
    self.store = store
    self.attempts = max(1, attempts)
    self.interval = interval
  }

  public func endpoint() async throws -> URL {
    let revision = operationRevision
    try check(revision)
    do { return try await readEndpoint(revision: revision) } catch {
      try check(revision)
      throw error
    }
  }

  private func readEndpoint(revision: Int) async throws -> URL {
    let app = await lifecycle.appURL()
    try check(revision)
    guard app != nil else { throw YandexClientError.appNotFound }
    let pids = await lifecycle.runningPIDs()
    try check(revision)
    guard !pids.isEmpty else { throw YandexClientError.appClosed }
    let session = await store.load()
    try check(revision)
    guard let session, pids.contains(session.pid) else { throw YandexClientError.requiresConnection }
    let running = await lifecycle.isRunning(session.pid)
    try check(revision)
    guard running else { throw YandexClientError.requiresConnection }
    let listeners = try await lifecycle.listeners(port: session.port)
    try check(revision)
    guard YandexEndpoint.isOwned(listeners, pid: session.pid, port: session.port) else {
      throw listeners.isEmpty ? YandexClientError.requiresConnection : YandexClientError.unsafeEndpoint
    }
    let data = try await http.targets(port: session.port)
    try check(revision)
    let stillRunning = await lifecycle.isRunning(session.pid)
    try check(revision)
    let currentListeners = try await lifecycle.listeners(port: session.port)
    try check(revision)
    guard stillRunning, YandexEndpoint.isOwned(currentListeners, pid: session.pid, port: session.port) else {
      throw YandexClientError.unsafeEndpoint
    }
    return try YandexEndpoint.websocket(from: data, port: session.port)
  }

  private func check(_ revision: Int) throws {
    guard !changing, operationRevision == revision else { throw YandexClientError.operationInProgress }
  }

  public func connect() async throws {
    guard !changing else { throw YandexClientError.operationInProgress }
    operationRevision += 1
    changing = true
    defer { changing = false }
    guard let app = await lifecycle.appURL() else { throw YandexClientError.appNotFound }
    let port = try await lifecycle.freePort()
    guard try await lifecycle.listeners(port: port).isEmpty else { throw YandexClientError.busyPort }
    try await terminateCurrent()
    guard try await lifecycle.listeners(port: port).isEmpty else { throw YandexClientError.busyPort }
    await store.save(nil)
    let pid = try await lifecycle.launch(app, arguments: ["--remote-debugging-address=127.0.0.1", "--remote-debugging-port=\(port)"])
    await store.save(YandexDebugSession(pid: pid, port: port))
    try await waitForEndpoint(pid: pid, port: port)
  }

  private func waitForEndpoint(pid: Int32, port: Int) async throws {
    for _ in 0..<attempts {
      try Task.checkCancellation()
      let listeners = try await lifecycle.listeners(port: port)
      if !listeners.isEmpty {
        guard YandexEndpoint.isOwned(listeners, pid: pid, port: port) else { throw YandexClientError.unsafeEndpoint }
        do {
          _ = try YandexEndpoint.websocket(from: await http.targets(port: port), port: port)
          guard await lifecycle.isRunning(pid),
            YandexEndpoint.isOwned(try await lifecycle.listeners(port: port), pid: pid, port: port)
          else { throw YandexClientError.unsafeEndpoint }
          return
        } catch YandexClientError.notReady {} catch {
          if error is CancellationError || error as? YandexClientError == .unsafeEndpoint { throw error }
        }
      }
      guard await lifecycle.isRunning(pid) else { throw YandexClientError.appClosed }
      try await Task.sleep(for: interval)
    }
    throw YandexClientError.launchTimeout
  }

  public func disconnect() async throws {
    guard !changing else { throw YandexClientError.operationInProgress }
    operationRevision += 1
    changing = true
    defer { changing = false }
    guard let app = await lifecycle.appURL() else { throw YandexClientError.appNotFound }
    try await terminateCurrent()
    await store.save(nil)
    _ = try await lifecycle.launch(app, arguments: [])
  }

  private func terminateCurrent() async throws {
    let pids = await lifecycle.runningPIDs()
    for pid in pids { try await lifecycle.terminate(pid) }
    for _ in 0..<attempts {
      try Task.checkCancellation()
      var running = false
      for pid in pids where await lifecycle.isRunning(pid) { running = true }
      if !running, await lifecycle.runningPIDs().isEmpty { return }
      try await Task.sleep(for: interval)
    }
    throw YandexClientError.terminationTimeout
  }
}
