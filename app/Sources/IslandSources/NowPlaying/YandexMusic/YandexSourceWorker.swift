import Foundation
import IslandCore

actor YandexSourceWorker {
  private let script: String
  private let client: any YandexClient
  private let makeConnection: @Sendable (URL) -> any CDPConnection
  private let loadArtwork: @Sendable (URL) async -> Data?
  private let interval: Duration
  private let gate: YandexSourceGate
  private let changes: AsyncStream<NowPlayingChange>.Continuation
  private let statuses: AsyncStream<NowPlayingSourceState>.Continuation
  private var generation = 0
  private var epoch = 0
  private var polling: Task<Void, Never>?
  private var events: Task<Void, Never>?
  private var commands: Task<Void, Never>?
  private var cleanup: Task<Void, Never>?
  private var connection: (any CDPConnection)?
  private var endpoint: URL?
  private var preloadID: String?
  private var needsInjection = true
  private var current: NowPlayingInfo?
  private var currentArtworkURL: String?
  private var status: NowPlayingSourceState?
  private var lastSampledAt = -Double.infinity
  private var loading: Task<Void, Never>?
  private var loadingRevision = 0
  private var artTasks: [UUID: Task<Void, Never>] = [:]
  private var artRequested: String?
  private var artworkCache: [String: Data] = [:]
  private var artworkOrder: [String] = []
  private var accents = AccentCache()

  init(
    script: String, client: any YandexClient, connection: @escaping @Sendable (URL) -> any CDPConnection,
    artwork: @escaping @Sendable (URL) async -> Data?, pollInterval: Duration, gate: YandexSourceGate,
    changes: AsyncStream<NowPlayingChange>.Continuation, statuses: AsyncStream<NowPlayingSourceState>.Continuation
  ) {
    self.script = script
    self.client = client
    makeConnection = connection
    loadArtwork = artwork
    interval = pollInterval
    self.gate = gate
    self.changes = changes
    self.statuses = statuses
  }

  func start(generation: Int, commands queue: AsyncStream<YandexSourceCommand>) async {
    guard gate.current(generation) else { return }
    await teardown()
    guard gate.current(generation) else { return }
    self.generation = generation
    lastSampledAt = -Double.infinity
    commands = Task {
      for await request in queue {
        await perform(
          request.name, value: request.value, expectedTrackID: request.expectedTrackID, action: request.action, token: request.token)
      }
    }
    polling = Task { await poll(generation: generation) }
  }
  func stop(upTo generation: Int) async {
    guard self.generation <= generation else { return }
    polling?.cancel()
    commands?.cancel()
    loading?.cancel()
    loading = nil
    await teardown()
    guard self.generation <= generation else { return }
    current = nil
    currentArtworkURL = nil
  }

  private func poll(generation: Int) async {
    var failures = 0
    while gate.current(generation), !Task.isCancelled {
      do {
        try await read(generation: generation)
        failures = 0
        try await Task.sleep(for: interval)
      } catch {
        guard gate.current(generation), !Task.isCancelled else { return }
        await teardown()
        guard gate.current(generation) else { return }
        if error as? YandexClientError == .appClosed || error as? YandexClientError == .requiresConnection
          || error as? YandexClientError == .appNotFound
        {
          clear()
        } else {
          awaitReadiness()
        }
        report(Self.state(for: error))
        failures = min(failures + 1, 5)
        do { try await Task.sleep(for: .milliseconds(250 * (1 << failures))) } catch { return }
      }
    }
  }

  private func read(generation: Int) async throws {
    let url = try await client.endpoint()
    guard gate.current(generation) else { return }
    if endpoint != url || connection == nil {
      await teardown()
      guard gate.current(generation) else { return }
      report(.connecting)
      let cdp = makeConnection(url)
      connection = cdp
      endpoint = url
      needsInjection = true
      let session = epoch
      events = Task { for await event in cdp.events { await receive(event, generation: generation, epoch: session) } }
      _ = try await cdp.request("Runtime.enable", params: .object([:]))
      _ = try await cdp.request("Page.enable", params: .object([:]))
      _ = try await cdp.request("Runtime.addBinding", params: .object(["name": .string("oasisYandexChanged")]))
      let preload = try await cdp.request("Page.addScriptToEvaluateOnNewDocument", params: .object(["source": .string(script)]))
      preloadID = preload["identifier"].string
    }
    guard let connection, gate.current(generation) else { return }
    let session = epoch
    if needsInjection {
      _ = try await evaluate(script, on: connection)
      guard valid(generation, session) else { return }
      needsInjection = false
    }
    let value = try await evaluate("window.__oasisYandexBridge?.snapshot()", on: connection)
    guard valid(generation, session) else { return }
    try accept(value, generation: generation, epoch: session)
  }

  private func valid(_ generation: Int, _ epoch: Int) -> Bool {
    gate.current(generation) && self.generation == generation && self.epoch == epoch
  }
  private func report(_ state: NowPlayingSourceState) {
    guard gate.current(generation), status != state else { return }
    status = state
    statuses.yield(state)
  }
  private func clear() {
    if current != nil {
      current = nil
      currentArtworkURL = nil
      changes.yield(.cleared)
    }
  }

  private func awaitReadiness() {
    guard current != nil, loading == nil else { return }
    loadingRevision += 1
    let revision = loadingRevision
    let session = generation
    loading = Task {
      do { try await Task.sleep(for: .seconds(3)) } catch { return }
      guard gate.current(session), loadingRevision == revision else { return }
      loading = nil
      clear()
    }
  }

  private func receive(_ event: CDPEvent, generation: Int, epoch: Int) async {
    guard valid(generation, epoch) else { return }
    switch event.method {
    case "Runtime.bindingCalled":
      guard event.params["name"].string == "oasisYandexChanged", let payload = event.params["payload"].string,
        let value = try? JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8))
      else { return }
      try? accept(value, generation: generation, epoch: epoch)
    case "Page.frameNavigated":
      guard event.params["frame"]["parentId"] == .null else { return }
      needsInjection = true
      awaitReadiness()
      report(.notReady)
    case "Runtime.executionContextsCleared":
      needsInjection = true
      awaitReadiness()
      report(.notReady)
    default: break
    }
  }

  private func evaluate(_ expression: String, on connection: any CDPConnection) async throws -> JSONValue {
    let result = try await connection.request(
      "Runtime.evaluate",
      params: .object([
        "expression": .string(expression), "returnByValue": .bool(true), "awaitPromise": .bool(true),
      ]))
    guard result["exceptionDetails"] == .null else { throw CDPError.remote("JavaScript evaluation failed") }
    return result["result"]["value"]
  }

  private func accept(_ value: JSONValue, generation: Int, epoch: Int) throws {
    guard valid(generation, epoch) else { return }
    if value == .null {
      needsInjection = true
      awaitReadiness()
      report(.notReady)
      return
    }
    let snapshot = try JSONDecoder().decode(YandexSnapshot.self, from: Data(value.json.utf8))
    guard snapshot.sampledAt >= lastSampledAt else { return }
    lastSampledAt = snapshot.sampledAt
    guard snapshot.version == 1 else {
      awaitReadiness()
      report(.incompatibleVersion)
      return
    }
    guard var info = snapshot.info else {
      awaitReadiness()
      report(snapshot.state == "incompatibleVersion" ? .incompatibleVersion : .notReady)
      return
    }
    loadingRevision += 1
    loading?.cancel()
    loading = nil
    let isNew = current?.sourceTrackID != info.sourceTrackID
    if !isNew, currentArtworkURL == snapshot.artworkURL {
      info.artwork = current?.artwork
      info.accent = current?.accent
      info.accentBottom = current?.accentBottom
    } else {
      artRequested = nil
    }
    currentArtworkURL = snapshot.artworkURL
    if let url = snapshot.artworkURL, let cached = artworkCache[url] { fill(&info, artwork: cached) }
    current = info
    changes.yield(isNew ? .newTrack(info) : .updated(info))
    report(.connected)
    guard let raw = snapshot.artworkURL, let url = URL(string: raw), info.artwork == nil,
      artRequested != raw, let track = info.sourceTrackID
    else { return }
    artRequested = raw
    let request = YandexArtworkRequest(id: UUID(), url: raw, track: track, generation: generation, epoch: epoch)
    artTasks[request.id] = Task {
      let data = await loadArtwork(url)
      artworkFinished(data, request: request)
    }
  }

}

private struct YandexArtworkRequest: Sendable {
  let id: UUID
  let url: String
  let track: String
  let generation: Int
  let epoch: Int
}

extension YandexSourceWorker {
  private func artworkFinished(_ data: Data?, request: YandexArtworkRequest) {
    artTasks[request.id] = nil
    let url = request.url
    guard valid(request.generation, request.epoch), current?.sourceTrackID == request.track, currentArtworkURL == url,
      let data, var info = current
    else { return }
    artworkCache[url] = data
    artworkOrder.removeAll { $0 == url }
    artworkOrder.append(url)
    while artworkOrder.count > 16 { artworkCache[artworkOrder.removeFirst()] = nil }
    fill(&info, artwork: data)
    current = info
    changes.yield(.updated(info))
  }
  private func fill(_ info: inout NowPlayingInfo, artwork: Data) {
    info.artwork = artwork
    switch accents.lookup(info.trackKey, artwork: artwork) {
    case .hit(let colors):
      info.accent = colors.accent
      info.accentBottom = colors.bottom
    case .knownFailure: break
    case .miss:
      let colors = ArtworkColor.accentAndBottom(of: artwork).map { AccentCache.Colors(accent: $0.accent, bottom: $0.bottom) }
      accents.store(info.trackKey, colors: colors, artwork: artwork)
      info.accent = colors?.accent
      info.accentBottom = colors?.bottom
    }
  }

  private func perform(_ name: String, value: JSONValue, expectedTrackID: String?, action: PlayerAction, token: YandexCommandToken) async {
    guard gate.current(token.generation) else { return }
    let session = epoch
    do {
      guard let connection, current != nil else { throw CDPError.disconnected }
      var request: [String: JSONValue] = ["action": .string(name), "value": value]
      if let expected = expectedTrackID ?? current?.sourceTrackID { request["expectedTrackID"] = .string(expected) }
      guard valid(token.generation, session) else { return }
      let result = try await evaluate("window.__oasisYandexBridge.command(\(JSONValue.object(request).json))", on: connection)
      guard valid(token.generation, session) else { return }
      try accept(result["snapshot"], generation: token.generation, epoch: session)
      guard result["ok"].bool == true else { throw CDPError.remote(result["error"].string ?? "Command failed") }
      if gate.current(token) { statuses.yield(.connected) }
    } catch {
      guard gate.current(token), valid(token.generation, session) else { return }
      statuses.yield(.commandFailed(action, String(describing: error)))
    }
  }

  private func teardown() async {
    epoch += 1
    events?.cancel()
    events = nil
    for task in artTasks.values { task.cancel() }
    artTasks.removeAll()
    artRequested = nil
    let old = connection
    let preload = preloadID
    connection = nil
    endpoint = nil
    preloadID = nil
    needsInjection = true
    guard let old else {
      await cleanup?.value
      return
    }
    let previous = cleanup
    let work = Task {
      await previous?.value
      // Завершение не ждёт зависший renderer дольше 200 мс.
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          _ = try? await old.request("Runtime.evaluate", params: .object(["expression": .string("window.__oasisYandexBridge?.dispose()")]))
          _ = try? await old.request("Runtime.removeBinding", params: .object(["name": .string("oasisYandexChanged")]))
          if let preload {
            _ = try? await old.request("Page.removeScriptToEvaluateOnNewDocument", params: .object(["identifier": .string(preload)]))
          }
        }
        group.addTask { try? await Task.sleep(for: .milliseconds(200)) }
        _ = await group.next()
        group.cancelAll()
        await old.close()
      }
    }
    cleanup = work
    await work.value
  }

  private static func state(for error: any Error) -> NowPlayingSourceState {
    switch error {
    case YandexClientError.appNotFound: .appNotFound
    case YandexClientError.appClosed: .appClosed
    case YandexClientError.requiresConnection: .requiresConnection
    case YandexClientError.operationInProgress: .connecting
    case YandexClientError.notReady: .notReady
    default: .failed(String(describing: error))
    }
  }
}
