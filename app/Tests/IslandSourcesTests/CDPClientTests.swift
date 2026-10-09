import Foundation
import Testing

@testable import IslandSources

actor TestCDPSocket: CDPSocket {
  var sent: [String] = []
  var waiting: CheckedContinuation<String, any Error>?
  var queued: [String] = []
  var ended = false
  func send(_ message: String) async throws { sent.append(message) }
  func receive() async throws -> String {
    if !queued.isEmpty { return queued.removeFirst() }
    if ended { throw CDPError.disconnected }
    return try await withCheckedThrowingContinuation { waiting = $0 }
  }
  func close() async { fail() }
  func reply(_ message: String) {
    if let pending = waiting {
      waiting = nil
      pending.resume(returning: message)
    } else {
      queued.append(message)
    }
  }
  func fail() {
    ended = true
    waiting?.resume(throwing: CDPError.disconnected)
    waiting = nil
  }
  func ids(count: Int) async -> [Int] {
    for _ in 0..<200 {
      if sent.count >= count { break }
      try? await Task.sleep(for: .milliseconds(2))
    }
    return sent.compactMap { try? JSONDecoder().decode(JSONValue.self, from: Data($0.utf8))["id"].int }
  }
}
struct CDPClientTests {
  @Test("Ответы CDP сопоставляются по id, даже если пришли в обратном порядке")
  func outOfOrder() async throws {
    let socket = TestCDPSocket()
    let client = CDPClient(socket: socket, timeout: .seconds(1))
    let first = Task { try await client.request("one") }
    let firstIDs = await socket.ids(count: 1)
    let second = Task { try await client.request("two") }
    let ids = await socket.ids(count: 2)
    try #require(ids.count == 2)
    try #require(firstIDs.count == 1)
    await socket.reply("{\"id\":\(ids[1]),\"result\":{\"value\":2}}")
    await socket.reply("{\"id\":\(firstIDs[0]),\"result\":{\"value\":1}}")
    #expect(try await first.value["value"].int == 1)
    #expect(try await second.value["value"].int == 2)
    await client.close()
  }
  @Test("Обрыв сокета завершает все ожидающие запросы")
  func disconnect() async {
    let socket = TestCDPSocket()
    let client = CDPClient(socket: socket)
    let request = Task { try await client.request("Runtime.evaluate") }
    _ = await socket.ids(count: 1)
    await socket.fail()
    await #expect(throws: CDPError.disconnected) { try await request.value }
  }
  @Test("Запрос CDP ограничен таймаутом и поддерживает отмену")
  func timeoutAndCancellation() async {
    let socket = TestCDPSocket()
    let client = CDPClient(socket: socket, timeout: .milliseconds(20))
    await #expect(throws: CDPError.timeout) { try await client.request("missing") }
    let request = Task { try await client.request("cancel") }
    _ = await socket.ids(count: 2)
    request.cancel()
    await #expect(throws: CancellationError.self) { try await request.value }
    await client.close()
  }
  @Test("Ошибка протокола возвращается запросу, malformed сообщение закрывает транспорт")
  func protocolErrors() async throws {
    let socket = TestCDPSocket()
    let client = CDPClient(socket: socket)
    let request = Task { try await client.request("unknown") }
    let ids = await socket.ids(count: 1)
    let id = try #require(ids.first)
    await socket.reply("{\"id\":\(id),\"error\":{\"message\":\"unsupported\"}}")
    await #expect(throws: CDPError.remote("unsupported")) { try await request.value }
    let next = Task { try await client.request("read") }
    _ = await socket.ids(count: 2)
    await socket.reply("malformed")
    await #expect(throws: CDPError.disconnected) { try await next.value }
  }

}
