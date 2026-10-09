import Foundation

public enum CDPError: Error, Equatable, Sendable {
  case disconnected, timeout, invalidMessage
  case remote(String)
}
public protocol CDPSocket: Sendable {
  func send(_ message: String) async throws
  func receive() async throws -> String
  func close() async
}
public struct CDPEvent: Sendable {
  public var method: String
  public var params: JSONValue
}
public protocol CDPConnection: Sendable {
  var events: AsyncStream<CDPEvent> { get }
  func request(_ method: String, params: JSONValue) async throws -> JSONValue
  func close() async
}

public actor CDPClient: CDPConnection {
  public nonisolated let events: AsyncStream<CDPEvent>
  private let continuation: AsyncStream<CDPEvent>.Continuation
  private let socket: any CDPSocket
  private let timeout: Duration
  private var nextID = 0
  private var closed = false
  private var reader: Task<Void, Never>?
  private var sender: Task<Void, Never>?
  private struct Pending {
    let continuation: CheckedContinuation<JSONValue, any Error>
    let timer: Task<Void, Never>
  }
  private var pending: [Int: Pending] = [:]

  public init(socket: any CDPSocket, timeout: Duration = .seconds(4)) {
    self.socket = socket
    self.timeout = timeout
    (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(32))
  }

  public func request(_ method: String, params: JSONValue = .object([:])) async throws -> JSONValue {
    guard !closed else { throw CDPError.disconnected }
    if reader == nil { reader = Task { await receiveLoop() } }
    nextID += 1
    let id = nextID
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { response in
        guard !Task.isCancelled else {
          response.resume(throwing: CancellationError())
          return
        }
        let timer = Task { [timeout] in
          do {
            try await Task.sleep(for: timeout)
            expire(id, error: CDPError.timeout)
          } catch {}
        }
        pending[id] = Pending(continuation: response, timer: timer)
        let message = JSONValue.object(["id": .number(Double(id)), "method": .string(method), "params": params]).json
        let previous = sender
        sender = Task {
          await previous?.value
          guard !closed, pending[id] != nil else { return }
          do { try await socket.send(message) } catch { await fail() }
        }
      }
    } onCancel: {
      Task { await self.expire(id, error: CancellationError()) }
    }
  }

  private func receiveLoop() async {
    do {
      while !closed {
        let text = try await socket.receive()
        guard !closed else { return }
        let response = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        if let id = response["id"].int, let waiter = pending.removeValue(forKey: id) {
          waiter.timer.cancel()
          if response["error"] != .null {
            waiter.continuation.resume(throwing: CDPError.remote(response["error"]["message"].string ?? "CDP error"))
          } else {
            waiter.continuation.resume(returning: response["result"])
          }
        } else if let method = response["method"].string {
          continuation.yield(CDPEvent(method: method, params: response["params"]))
        }
      }
    } catch { await fail() }
  }

  private func expire(_ id: Int, error: any Error) {
    guard let waiter = pending.removeValue(forKey: id) else { return }
    waiter.timer.cancel()
    waiter.continuation.resume(throwing: error)
  }
  private func fail() async { await close() }
  public func close() async {
    guard !closed else { return }
    closed = true
    reader?.cancel()
    sender?.cancel()
    for id in Array(pending.keys) { expire(id, error: CDPError.disconnected) }
    continuation.finish()
    await socket.close()
  }
}

public actor URLSessionCDPSocket: CDPSocket {
  private let session: URLSession
  private let task: URLSessionWebSocketTask
  public init(url: URL) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.connectionProxyDictionary = [:]
    configuration.httpCookieStorage = nil
    let session = URLSession(configuration: configuration, delegate: YandexNoRedirects(), delegateQueue: nil)
    self.session = session
    task = session.webSocketTask(with: url)
    task.resume()
  }
  public func send(_ message: String) async throws { try await task.send(.string(message)) }
  public func receive() async throws -> String {
    switch try await task.receive() {
    case .string(let value): return value
    case .data(let value):
      guard let text = String(data: value, encoding: .utf8) else { throw CDPError.invalidMessage }
      return text
    @unknown default: throw CDPError.invalidMessage
    }
  }
  public func close() async {
    task.cancel(with: .goingAway, reason: nil)
    session.invalidateAndCancel()
  }
}
