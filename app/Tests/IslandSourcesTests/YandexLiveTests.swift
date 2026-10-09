import Foundation
import IslandCore
import Testing

@testable import IslandSources

struct YandexLiveTests {
  @Test(
    "Живой клиент подключается и закрывает порт обычным перезапуском",
    .enabled(if: ProcessInfo.processInfo.environment["YANDEX_LIVE_RESTART"] == "1"))
  func restartLifecycle() async throws {
    let store = MemoryYandexSessionStore()
    let lifecycle = SystemYandexLifecycle()
    let client = YandexMusicClient(lifecycle: lifecycle, store: store)
    do {
      try await client.connect()
      let session = try #require(await store.load())
      let endpoint = try await client.endpoint()
      #expect(endpoint.host == "127.0.0.1")
      #expect(YandexEndpoint.isOwned(try await lifecycle.listeners(port: session.port), pid: session.pid, port: session.port))
      if ProcessInfo.processInfo.environment["YANDEX_LIVE_PLAYBACK"] == "1" { try await verifyPlayback(endpoint) }
      try await client.disconnect()
      #expect(await store.load() == nil)
      #expect(try await lifecycle.listeners(port: session.port).isEmpty)
      #expect(await lifecycle.runningPIDs().count == 1)
      do {
        _ = try await client.endpoint()
        Issue.record("Обычный запуск не должен сохранять подключение CDP")
      } catch {
        #expect(error as? YandexClientError == .requiresConnection)
      }
      print("Swift lifecycle: loopback CDP connected; port \(session.port) closed; ordinary client running")
    } catch {
      try? await client.disconnect()
      throw error
    }
  }

  private func verifyPlayback(_ endpoint: URL) async throws {
    let connection = CDPClient(socket: URLSessionCDPSocket(url: endpoint))
    do {
      _ = try await connection.request("Runtime.enable")
      let script = try String(contentsOf: scriptURL, encoding: .utf8)
      var snapshot: YandexSnapshot?
      for _ in 0..<50 {
        let value = try await evaluate(script, on: connection)
        snapshot = try JSONDecoder().decode(YandexSnapshot.self, from: Data(value.json.utf8))
        if snapshot?.info != nil { break }
        try await Task.sleep(for: .milliseconds(100))
      }
      let info = try #require(snapshot?.info)
      let track = try #require(info.sourceTrackID)
      let duration = try #require(info.duration)
      let first = try await command(["action": .string("toggle")], on: connection)
      #expect(first["snapshot"]["isPlaying"].bool == !info.isPlaying)
      let second = try await command(["action": .string("toggle")], on: connection)
      #expect(second["snapshot"]["isPlaying"].bool == info.isPlaying)
      _ = try await command(["action": .string("pause")], on: connection)
      for target in [0, duration / 2, max(0, duration - 2)] {
        let result = try await command(
          ["action": .string("seek"), "value": .number(target), "expectedTrackID": .string(track)], on: connection)
        #expect(result["snapshot"]["trackID"].string == track)
        #expect(abs((result["snapshot"]["position"].double ?? -1) - target) <= 0.35)
      }
      _ = try await command(
        ["action": .string("seek"), "value": .number(info.elapsed ?? 0), "expectedTrackID": .string(track)], on: connection)
      if info.isPlaying { _ = try await command(["action": .string("play")], on: connection) }
      _ = try await evaluate("window.__oasisYandexBridge?.dispose()", on: connection)
      await connection.close()
      print("Swift CDP/bridge: track=\(track); rapid toggles confirmed; seek 0/middle/end confirmed; position restored")
    } catch {
      await connection.close()
      throw error
    }
  }

  private var scriptURL: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Resources/YandexMusic/player-bridge.js")
  }

  private func evaluate(_ expression: String, on connection: CDPClient) async throws -> JSONValue {
    let response = try await connection.request(
      "Runtime.evaluate", params: .object(["expression": .string(expression), "returnByValue": .bool(true), "awaitPromise": .bool(true)]))
    #expect(response["exceptionDetails"] == .null)
    return response["result"]["value"]
  }

  private func command(_ request: [String: JSONValue], on connection: CDPClient) async throws -> JSONValue {
    let result = try await evaluate("window.__oasisYandexBridge.command(\(JSONValue.object(request).json))", on: connection)
    try #require(result["ok"].bool == true, "\(request["action"]?.string ?? "unknown"): \(result["error"].string ?? "no error")")
    return result
  }

  @Test(
    "Живой Swift CDP читает трек и закрывается без команд аккаунта",
    .enabled(if: ProcessInfo.processInfo.environment["YANDEX_CDP_PORT"] != nil))
  func readOnly() async throws {
    let environment = ProcessInfo.processInfo.environment
    let port = try #require(environment["YANDEX_CDP_PORT"].flatMap(Int.init))
    let pid = try #require(environment["YANDEX_CDP_PID"].flatMap(Int32.init))
    let store = MemoryYandexSessionStore()
    await store.save(YandexDebugSession(pid: pid, port: port))
    let client = YandexMusicClient(store: store)
    let endpoint = try await client.endpoint()
    let connection = CDPClient(socket: URLSessionCDPSocket(url: endpoint))
    _ = try await connection.request("Runtime.enable")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)
    let value = try await connection.request(
      "Runtime.evaluate", params: .object(["expression": .string(script), "returnByValue": .bool(true)]))
    #expect(value["exceptionDetails"] == .null)
    let snapshot = try JSONDecoder().decode(YandexSnapshot.self, from: Data(value["result"]["value"].json.utf8))
    let direct = try #require(snapshot.info)
    #expect(direct.sourceTrackID != nil)
    _ = try await connection.request("Runtime.evaluate", params: .object(["expression": .string("window.__oasisYandexBridge?.dispose()")]))
    await connection.close()
    let source = YandexMusicSource(script: script, client: client)
    source.start()
    defer { source.stop() }
    let info = try await withThrowingTaskGroup(of: NowPlayingInfo.self) { group in
      group.addTask {
        for await change in source.changes {
          if case .newTrack(let info) = change { return info }
        }
        throw CDPError.disconnected
      }
      group.addTask {
        try await Task.sleep(for: .seconds(8))
        throw CDPError.timeout
      }
      defer { group.cancelAll() }
      return try await #require(group.next())
    }
    #expect(info.sourceTrackID == direct.sourceTrackID)
    print(
      "Swift CDP/source: track=\(info.sourceTrackID ?? "nil"), seek=\(info.capabilities.canSeek), favorite=\(info.isFavorite.map(String.init) ?? "unknown"), repeat=\(info.capabilities.repeatModes)"
    )
  }
}
