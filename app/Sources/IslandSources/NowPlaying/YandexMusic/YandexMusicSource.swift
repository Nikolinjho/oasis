import Foundation
import IslandCore
import os

public typealias YandexNowPlayingSource = YandexMusicSource

public final class YandexMusicSource: YandexSourceControlling, Sendable {
  public let changes: AsyncStream<NowPlayingChange>
  public let statuses: AsyncStream<NowPlayingSourceState>
  private let gate: YandexSourceGate
  private let worker: YandexSourceWorker

  public init(
    script: String, client: any YandexClient = YandexMusicClient.shared,
    connection: @escaping @Sendable (URL) -> any CDPConnection = { CDPClient(socket: URLSessionCDPSocket(url: $0)) },
    artwork: (@Sendable (URL) async -> Data?)? = nil,
    pollInterval: Duration = .seconds(1)
  ) {
    let (changes, changeContinuation) = AsyncStream<NowPlayingChange>.makeStream(bufferingPolicy: .bufferingNewest(8))
    let (statuses, statusContinuation) = AsyncStream<NowPlayingSourceState>.makeStream(bufferingPolicy: .bufferingNewest(8))
    self.changes = changes
    self.statuses = statuses
    let gate = YandexSourceGate()
    self.gate = gate
    worker = YandexSourceWorker(
      script: script, client: client, connection: connection, artwork: artwork ?? { await YandexArtworkLoader.shared.load($0) },
      pollInterval: pollInterval, gate: gate, changes: changeContinuation, statuses: statusContinuation)
  }

  public func start() {
    let session = gate.start()
    let worker = self.worker
    YandexSourceTransitions.enqueue { await worker.start(generation: session.generation, commands: session.commands) }
  }
  public func stop() {
    let generation = gate.stop()
    let worker = self.worker
    YandexSourceTransitions.enqueue { await worker.stop(upTo: generation) }
  }
  public func send(_ command: MediaCommand) {
    let action: String
    switch command {
    case .play: action = "play"
    case .pause: action = "pause"
    case .togglePlayPause: action = "toggle"
    case .nextTrack: action = "next"
    case .previousTrack: action = "previous"
    }
    enqueue(action, action: .media(command))
  }
  public func setShuffle(_ mode: Int) { enqueue("shuffle", value: .number(Double(mode)), action: .toggleShuffle) }
  public func setRepeat(_ mode: Int) { enqueue("repeat", value: .number(Double(mode)), action: .cycleRepeat) }
  public func seek(to position: TimeInterval) { enqueue("seek", value: .number(position), action: .seek(position)) }
  public func seek(to position: TimeInterval, expectedTrackID: String) {
    enqueue("seek", value: .number(position), expectedTrackID: expectedTrackID, action: .seek(position))
  }
  public func setFavorite(to favorite: Bool, expectedTrackID: String) {
    enqueue("favorite", value: .bool(favorite), expectedTrackID: expectedTrackID, action: .favorite)
  }
  private func enqueue(_ name: String, value: JSONValue = .null, expectedTrackID: String? = nil, action: PlayerAction) {
    gate.enqueue(name, value: value, expectedTrackID: expectedTrackID, action: action)
  }
}

struct YandexSourceCommand: Sendable {
  let name: String
  let value: JSONValue
  let expectedTrackID: String?
  let action: PlayerAction
  let token: YandexCommandToken
}
struct YandexSourceSession: Sendable {
  let generation: Int
  let commands: AsyncStream<YandexSourceCommand>
}
struct YandexCommandToken: Sendable {
  let generation: Int
  let name: String
  let revision: Int
}
final class YandexSourceGate: Sendable {
  private struct State {
    var generation = 0
    var stopped = true
    var revisions: [String: Int] = [:]
    var continuation: AsyncStream<YandexSourceCommand>.Continuation?
  }
  private let state = OSAllocatedUnfairLock(initialState: State())
  func start() -> YandexSourceSession {
    state.withLock {
      $0.continuation?.finish()
      let (stream, continuation) = AsyncStream<YandexSourceCommand>.makeStream()
      $0.continuation = continuation
      $0.generation += 1
      $0.stopped = false
      return YandexSourceSession(generation: $0.generation, commands: stream)
    }
  }
  func stop() -> Int {
    state.withLock {
      let old = $0.generation
      $0.generation += 1
      $0.stopped = true
      $0.continuation?.finish()
      $0.continuation = nil
      return old
    }
  }
  func current(_ generation: Int) -> Bool { state.withLock { !$0.stopped && $0.generation == generation } }
  func enqueue(_ name: String, value: JSONValue, expectedTrackID: String?, action: PlayerAction) {
    state.withLock {
      guard !$0.stopped else { return }
      $0.revisions[name, default: 0] += 1
      let token = YandexCommandToken(generation: $0.generation, name: name, revision: $0.revisions[name]!)
      $0.continuation?.yield(YandexSourceCommand(name: name, value: value, expectedTrackID: expectedTrackID, action: action, token: token))
    }
  }
  func current(_ token: YandexCommandToken) -> Bool {
    state.withLock { !$0.stopped && $0.generation == token.generation && $0.revisions[token.name] == token.revision }
  }
}

actor YandexArtworkLoader {
  static let shared = YandexArtworkLoader()
  private let session: URLSession
  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.timeoutIntervalForRequest = 10
    session = URLSession(configuration: configuration)
  }
  func load(_ url: URL) async -> Data? {
    guard url.scheme == "https", url.user == nil, url.password == nil else { return nil }
    do {
      let (data, response) = try await session.data(from: url)
      guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= 8_000_000 else { return nil }
      return data
    } catch { return nil }
  }
}
