import Foundation
import IslandCore

@MainActor
public final class CodexAppServerClient {
  public typealias Handler = @MainActor (CodexClientEvent) -> Void
  private enum Pending {
    case initialize
    case loaded(String?)
    case resume(String)
  }

  private var handler: Handler?
  private var socket: CodexWebSocket?
  private var generation = UUID()
  private var enabled = false
  private var ready = false
  private var nextID: Int64 = 0
  private var pending: [CodexRequestID: Pending] = [:]
  private var questions: [CodexQuestionIdentity: CodexQuestionnaire] = [:]
  private var sent: Set<CodexQuestionIdentity> = []
  private var resolved: Set<CodexQuestionIdentity> = []
  private var resolvedOrder: [CodexQuestionIdentity] = []
  private var subscribed: Set<String> = []
  private var resuming: Set<String> = []
  private var threads: [String: CodexThreadSummary] = [:]
  private var loaded: Set<String> = []
  private var listed: Set<String> = []
  private var listing = false
  private var poll: Task<Void, Never>?
  private var retry: Task<Void, Never>?
  private var timeout: Task<Void, Never>?
  private let socketPath: String

  public init(socketPath: String? = nil) {
    let home =
      ProcessInfo.processInfo.environment["CODEX_HOME"]
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path
    self.socketPath =
      socketPath
      ?? URL(fileURLWithPath: home)
      .appendingPathComponent("app-server-control/app-server-control.sock").path
  }

  public func start(_ handler: @escaping Handler) {
    self.handler = handler
    guard !enabled else { return }
    enabled = true
    connect()
  }

  public func stop() {
    enabled = false
    clearConnection()
    handler?(.connection(.stopped))
  }

  /// Запись ответа не означает принятие: завершение приходит только через resolved.
  @discardableResult
  public func answer(_ identity: CodexQuestionIdentity, answers: [String: [String]]) -> Bool {
    guard ready, identity.generation == generation, let question = questions[identity],
      !sent.contains(identity), Set(answers.keys) == Set(question.questions.map(\.id))
    else { return false }
    let payload = answers.mapValues { CodexJSON.object(["answers": .array($0.map(CodexJSON.string))]) }
    let id: CodexJSON
    switch identity.requestID {
    case .integer(let value): id = .number(value)
    case .string(let value): id = .string(value)
    }
    guard send(.object(["id": id, "result": .object(["answers": .object(payload)])])) else {
      handler?(.answerFailed(identity))
      return false
    }
    sent.insert(identity)
    return true
  }

  private func connect() {
    guard enabled else { return }
    generation = UUID()
    let current = generation
    handler?(.connection(.connecting))
    let connection = CodexWebSocket { [weak self] event in
      Task { @MainActor [weak self] in
        guard let self, self.enabled, self.generation == current else { return }
        self.receive(event)
      }
    }
    socket = connection
    connection.start(path: socketPath)
    timeout = Task { [weak self] in
      try? await Task.sleep(for: .seconds(15))
      guard !Task.isCancelled, let self, !self.ready else { return }
      self.disconnected("Истекло время инициализации Codex")
    }
  }

  private func receive(_ event: CodexWebSocket.Event) {
    switch event {
    case .opened:
      request(
        "initialize",
        params: .object([
          "clientInfo": .object(["name": .string("oasis"), "version": .string("1.0")]),
          "capabilities": .object(["experimentalApi": .bool(true)]),
        ]), purpose: .initialize)
    case .closed(let reason): disconnected(reason)
    case .message(let data):
      guard let message = try? JSONDecoder().decode(CodexJSON.self, from: data) else {
        disconnected("Некорректное сообщение Codex")
        return
      }
      if let method = message["method"]?.string {
        notification(method, message: message)
      } else if let id = message["id"]?.decode(CodexRequestID.self), let purpose = pending.removeValue(forKey: id) {
        response(purpose, result: message["result"], failed: message["error"] != nil)
      }
    }
  }

  private func clearConnection() {
    let previous = generation
    generation = UUID()
    poll?.cancel()
    retry?.cancel()
    timeout?.cancel()
    poll = nil
    retry = nil
    timeout = nil
    socket?.stop()
    socket = nil
    ready = false
    resolved.removeAll()
    resolvedOrder.removeAll()
    pending.removeAll()
    questions.removeAll()
    sent.removeAll()
    subscribed.removeAll()
    resuming.removeAll()
    threads.removeAll()
    loaded.removeAll()
    listing = false
    listed.removeAll()
    handler?(.invalidated(previous))
  }

  private func disconnected(_ reason: String) {
    clearConnection()
    guard enabled else { return }
    handler?(.connection(.waiting(reason)))
    retry = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      self?.connect()
    }
  }

  @discardableResult
  private func send(_ message: CodexJSON) -> Bool {
    guard let socket, let data = try? JSONEncoder().encode(message), data.count <= 1_048_576 else { return false }
    socket.send(data)
    return true
  }

  private func request(_ method: String, params: CodexJSON, purpose: Pending) {
    nextID += 1
    let id = CodexRequestID.integer(nextID)
    let current = generation
    pending[id] = purpose
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(30))
      guard let self, self.generation == current, self.pending[id] != nil else { return }
      self.disconnected("Истекло время ответа Codex")
    }
    send(.object(["id": .number(nextID), "method": .string(method), "params": params]))
  }

  private func list(cursor: String? = nil) {
    if cursor == nil { listed.removeAll() }
    listing = true
    var params: [String: CodexJSON] = ["limit": .number(100)]
    if let cursor { params["cursor"] = .string(cursor) }
    request("thread/loaded/list", params: .object(params), purpose: .loaded(cursor))
  }

  private func subscribe(_ id: String) {
    guard loaded.contains(id), !subscribed.contains(id), !resuming.contains(id) else { return }
    resuming.insert(id)
    // Только ID из loaded/list. Для работающего thread сервер присоединяет клиента,
    // не применяя настройки. Никаких model/cwd/config/permissions overrides.
    request("thread/resume", params: .object(["threadId": .string(id), "excludeTurns": .bool(true)]), purpose: .resume(id))
  }

  private func response(_ purpose: Pending, result: CodexJSON?, failed: Bool) {
    switch purpose {
    case .initialize:
      guard !failed, result != nil else { return disconnected("Codex отклонил инициализацию") }
      initialized()
    case .loaded:
      loadedPage(result, failed: failed)
    case .resume(let id):
      resuming.remove(id)
      guard loaded.contains(id), !failed, let thread = result?["thread"]?.decode(CodexThreadSummary.self) else { return }
      subscribed.insert(id)
      threads[id] = thread
      handler?(.thread(thread))
    }
  }

  private func initialized() {
    send(.object(["method": .string("initialized")]))
    ready = true
    timeout?.cancel()
    timeout = nil
    handler?(.connection(.connected))
    list()
    poll = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled, let self else { return }
        if !self.listing { self.list() }
      }
    }
  }

  private func loadedPage(_ result: CodexJSON?, failed: Bool) {
    guard !failed, let page = result?.decode(CodexLoadedThreads.self) else {
      listing = false
      return
    }
    for id in page.data {
      listed.insert(id)
      loaded.insert(id)
      subscribe(id)
    }
    if let cursor = page.nextCursor {
      list(cursor: cursor)
    } else {
      for id in loaded.subtracting(listed) { forgetThread(id) }
      listing = false
    }
  }

}

extension CodexAppServerClient {
  private func notification(_ method: String, message: CodexJSON) {
    guard let params = message["params"] else { return }
    switch method {
    case "item/tool/requestUserInput":
      receivedQuestion(message, params: params)
    case "serverRequest/resolved":
      receivedResolution(params)
    case "thread/started":
      guard let thread = params["thread"]?.decode(CodexThreadSummary.self) else { return }
      threads[thread.id] = thread
      handler?(.thread(thread))
      if !listing { list() }
    case "thread/closed", "thread/deleted":
      if let id = params["threadId"]?.string { forgetThread(id) }
    case "thread/status/changed", "thread/name/updated":
      updateThread(method, params: params)
    default: break
    }
  }

  private func receivedQuestion(_ message: CodexJSON, params: CodexJSON) {
    guard let id = message["id"]?.decode(CodexRequestID.self),
      let input = params.decode(CodexInputParams.self)
    else { return }
    let identity = CodexQuestionIdentity(generation: generation, threadID: input.threadId, requestID: id)
    guard questions[identity] == nil, !resolved.contains(identity) else { return }
    let form = CodexQuestionnaire(
      id: identity, turnID: input.turnId, itemID: input.itemId,
      questions: input.questions, isBlocking: input.isBlocking)
    questions[identity] = form
    handler?(.question(form))
  }

  private func receivedResolution(_ params: CodexJSON) {
    guard let id = params["requestId"]?.decode(CodexRequestID.self), let thread = params["threadId"]?.string else { return }
    let identity = CodexQuestionIdentity(generation: generation, threadID: thread, requestID: id)
    rememberResolved(identity)
    questions.removeValue(forKey: identity)
    sent.remove(identity)
    handler?(.resolved(identity))
  }

  private func updateThread(_ method: String, params: CodexJSON) {
    guard let id = params["threadId"]?.string, var thread = threads[id] else { return }
    if method == "thread/status/changed", let status = params["status"]?.decode(CodexThreadSummary.Status.self) {
      if status.type == "notLoaded" {
        forgetThread(id)
        return
      }
      thread.status = status
    } else if method == "thread/name/updated" {
      thread.name = params["threadName"]?.string
    }
    threads[id] = thread
    handler?(.thread(thread))
  }

  private func forgetThread(_ id: String) {
    loaded.remove(id)
    listed.remove(id)
    subscribed.remove(id)
    resuming.remove(id)
    threads.removeValue(forKey: id)
    let identities = questions.keys.filter { $0.threadID == id }
    for identity in identities {
      rememberResolved(identity)
      questions.removeValue(forKey: identity)
      sent.remove(identity)
    }
    handler?(.threadClosed(id))
  }

  private func rememberResolved(_ identity: CodexQuestionIdentity) {
    guard resolved.insert(identity).inserted else { return }
    resolvedOrder.append(identity)
    if resolvedOrder.count > 1024 { resolved.remove(resolvedOrder.removeFirst()) }
  }

}
