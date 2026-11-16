import Darwin
import Foundation
import IslandCore

/// Запрашивает только лимиты через stdio app-server. Сессии и ходы не создаются.
@MainActor
public final class CodexLimitsSource {
  public enum Update: Sendable {
    case limits(CodexLimits)
    case unavailable(String)
  }

  private var process: Process?
  private var input: FileHandle?
  private var output: FileHandle?
  private var buffer = Data()
  private var ready = false
  private var nextID = 1
  private var pendingID: Int?
  private var generation = UUID()
  private var polling: Task<Void, Never>?
  private var timeout: Task<Void, Never>?
  private var handler: (@MainActor (Update) -> Void)?
  private let executable: URL?

  public init(executable: URL? = nil) {
    self.executable = executable ?? Self.findExecutable()
  }

  public func start(_ handler: @escaping @MainActor (Update) -> Void) {
    stop()
    self.handler = handler
    connect()
    polling = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled, let self else { return }
        if self.process == nil { self.connect() } else if self.ready { self.refresh() }
      }
    }
  }

  public func stop() {
    polling?.cancel()
    polling = nil
    handler = nil
    disconnect()
  }

  public func refresh() {
    if process == nil {
      connect()
      return
    }
    guard ready, pendingID == nil else { return }
    nextID += 1
    pendingID = nextID
    send(["id": nextID, "method": "account/rateLimits/read"])
    armTimeout()
  }

  private func connect() {
    guard let executable else { return fail("Установи Codex CLI и войди в аккаунт через codex login.") }
    let current = generation
    let process = Process()
    process.executableURL = executable
    process.arguments = ["app-server", "--listen", "stdio://"]
    process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    let incoming = Pipe()
    let outgoing = Pipe()
    process.standardInput = incoming
    process.standardOutput = outgoing
    process.standardError = FileHandle.nullDevice
    input = incoming.fileHandleForWriting
    output = outgoing.fileHandleForReading
    guard fcntl(incoming.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1) != -1 else {
      return fail("Не удалось настроить соединение с Codex.")
    }
    output?.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      if data.isEmpty { handle.readabilityHandler = nil }
      Task { @MainActor [weak self] in
        guard let self, self.generation == current else { return }
        if data.isEmpty { self.fail("Соединение с Codex закрыто.") } else { self.receive(data) }
      }
    }
    process.terminationHandler = { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.generation == current else { return }
        self.fail("Codex недоступен. Проверь вход через codex login.")
      }
    }
    self.process = process
    do {
      try process.run()
      send([
        "id": 1, "method": "initialize",
        "params": ["clientInfo": ["name": "oasis_limits", "version": "0.1.0"]],
      ])
      armTimeout()
    } catch {
      fail("Не удалось запустить Codex CLI.")
    }
  }

  private func receive(_ data: Data) {
    buffer.append(data)
    guard buffer.count <= 1_048_576 else { return fail("Ответ Codex слишком большой.") }
    while let end = buffer.firstIndex(of: 10) {
      let line = Data(buffer[..<end])
      buffer.removeSubrange(...end)
      guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
      if object["method"] as? String == "account/rateLimits/updated" {
        refresh()
      } else if let id = object["id"] as? Int {
        if id == 1, !ready {
          guard object["result"] != nil else { return fail("Не удалось подключиться к Codex.") }
          timeout?.cancel()
          ready = true
          send(["method": "initialized"])
          refresh()
        } else if id == pendingID {
          pendingID = nil
          timeout?.cancel()
          if let result = object["result"] as? [String: Any] {
            publish(result)
          } else {
            handler?(.unavailable("Лимиты недоступны. Проверь вход в Codex через аккаунт ChatGPT."))
          }
        }
      }
    }
  }

  private func publish(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object), let limits = CodexLimits.parse(data) else {
      handler?(.unavailable("Codex не вернул лимиты подписки."))
      return
    }
    handler?(.limits(limits))
  }

  private func send(_ object: [String: Any]) {
    guard let input, var data = try? JSONSerialization.data(withJSONObject: object) else { return }
    data.append(10)
    do { try input.write(contentsOf: data) } catch { fail("Не удалось отправить запрос лимитов Codex.") }
  }

  private func armTimeout() {
    timeout?.cancel()
    timeout = Task { [weak self] in
      try? await Task.sleep(for: .seconds(20))
      guard !Task.isCancelled else { return }
      self?.fail("Codex не ответил. Повторим запрос через минуту.")
    }
  }

  private func fail(_ message: String) {
    disconnect()
    handler?(.unavailable(message))
  }

  private func disconnect() {
    generation = UUID()
    timeout?.cancel()
    timeout = nil
    output?.readabilityHandler = nil
    try? input?.close()
    try? output?.close()
    input = nil
    output = nil
    process?.terminationHandler = nil
    if process?.isRunning == true { process?.terminate() }
    process = nil
    ready = false
    nextID = 1
    pendingID = nil
    buffer.removeAll()
  }

  private static func findExecutable() -> URL? {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let paths = [
      home.appendingPathComponent(".local/bin/codex").path,
      "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/Applications/Codex.app/Contents/Resources/codex",
    ]
    return paths.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
  }
}
