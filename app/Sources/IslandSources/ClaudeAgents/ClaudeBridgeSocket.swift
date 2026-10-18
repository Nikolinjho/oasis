import Darwin
import Foundation
import IslandCore

private final class ClaudeBridgeConnection {
  let descriptor: Int32
  let source: DispatchSourceRead
  let opened = ContinuousClock.now
  var input = Data()
  var handshaken = false
  var request: ClaudeRequest?
  var heartbeat = ContinuousClock.now
  var responseID: UUID?
  var completion: CheckedContinuation<Void, any Error>?
  var responseSentAt: ContinuousClock.Instant?
  var deadline: ContinuousClock.Instant?
  var accepted = false

  init(descriptor: Int32, queue: DispatchQueue) {
    self.descriptor = descriptor
    source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
  }
}

public final class ClaudeBridgeSocket: @unchecked Sendable {

  public let paths: ClaudeBridgePaths
  private let queue = DispatchQueue(label: "oasis.claude.bridge", qos: .userInitiated)
  private let queueKey = DispatchSpecificKey<Void>()
  private var listener: Int32 = -1
  private var lock: Int32 = -1
  private var listenerSource: DispatchSourceRead?
  private var timer: DispatchSourceTimer?
  private var connections: [Int32: ClaudeBridgeConnection] = [:]
  private var acknowledged: [ClaudeRequestID: UUID] = [:]
  private var callback: (@Sendable (ClaudeBridgeMessage) -> Void)?
  private var launchID = UUID()

  public init(paths: ClaudeBridgePaths = ClaudeBridgePaths()) {
    self.paths = paths
    queue.setSpecific(key: queueKey, value: ())
  }

  deinit { stop() }

  public func start(onMessage: @escaping @Sendable (ClaudeBridgeMessage) -> Void) throws {
    try queue.sync {
      guard listener < 0 else { return }
      try paths.prepare()
      lock = open(paths.lock.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
      var info = stat()
      guard lock >= 0, fstat(lock, &info) == 0, info.st_uid == getuid(),
        info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o777 == 0o600,
        flock(lock, LOCK_EX | LOCK_NB) == 0
      else {
        if lock >= 0 {
          close(lock)
          lock = -1
        }
        throw ClaudeBridgeError.busy
      }
      do {
        if lstat(paths.socket.path, &info) == 0 {
          guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK else { throw ClaudeBridgeError.unsafePath }
          guard unlink(paths.socket.path) == 0 else { throw ClaudeBridgeError.unsafePath }
        }
        listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { throw ClaudeBridgeError.unavailable }
        try ClaudeBridgeWire.configure(listener)
        var address = try paths.address()
        let result = withUnsafePointer(to: &address) {
          $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0, chmod(paths.socket.path, 0o600) == 0, listen(listener, 16) == 0 else {
          throw ClaudeBridgeError.unavailable
        }
        launchID = UUID()
        callback = onMessage
        let source = DispatchSource.makeReadSource(fileDescriptor: listener, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnections() }
        listenerSource = source
        source.resume()
        let clock = DispatchSource.makeTimerSource(queue: queue)
        clock.schedule(deadline: .now() + 1, repeating: 1)
        clock.setEventHandler { [weak self] in self?.checkDeadlines() }
        timer = clock
        clock.resume()
      } catch {
        stopOnQueue()
        throw error
      }
    }
  }

  public func stop() {
    if DispatchQueue.getSpecific(key: queueKey) != nil {
      stopOnQueue()
    } else {
      queue.sync { stopOnQueue() }
    }
  }

  public func cancel(requestID: ClaudeRequestID, reason: String) {
    queue.async { [self] in
      guard let connection = connections.values.first(where: { $0.request?.id == requestID }) else { return }
      try? ClaudeBridgeWire.send(.cancelled(requestID: requestID, reason: reason), to: connection.descriptor)
      closeConnection(connection, reason: reason)
    }
  }

  public func respond(requestID: ClaudeRequestID, responseID: UUID, answer: ClaudeAnswer) async throws {
    try await withCheckedThrowingContinuation { continuation in
      queue.async { [self] in
        if acknowledged[requestID] == responseID {
          continuation.resume()
          return
        }
        guard let connection = connections.values.first(where: { $0.request?.id == requestID }),
          let request = connection.request, let deadline = connection.deadline, deadline > ContinuousClock.now, connection.responseID == nil
        else {
          continuation.resume(throwing: ClaudeBridgeError.disconnected)
          return
        }
        do {
          _ = try ClaudeHookOutput.data(for: answer, request: request, validateDeadline: false)
          try ClaudeBridgeWire.send(.response(requestID: requestID, responseID: responseID, answer: answer), to: connection.descriptor)
          connection.responseID = responseID
          connection.responseSentAt = ContinuousClock.now
          connection.completion = continuation
        } catch {
          continuation.resume(throwing: error)
          closeConnection(connection, reason: "delivery-failed")
        }
      }
    }
  }

  private func acceptConnections() {
    while true {
      let descriptor = accept(listener, nil, nil)
      if descriptor < 0 {
        if errno == EINTR { continue }
        return
      }
      guard connections.count < ClaudeBridgeLimits.maximumConnections, ClaudeBridgeWire.sameUser(descriptor) else {
        close(descriptor)
        continue
      }
      do { try ClaudeBridgeWire.configure(descriptor) } catch {
        close(descriptor)
        continue
      }
      let connection = ClaudeBridgeConnection(descriptor: descriptor, queue: queue)
      connections[descriptor] = connection
      connection.source.setEventHandler { [weak self, weak connection] in
        guard let connection else { return }
        self?.read(connection)
      }
      connection.source.setCancelHandler { close(descriptor) }
      connection.source.resume()
    }
  }

  private func read(_ connection: ClaudeBridgeConnection) {
    var bytes = [UInt8](repeating: 0, count: 16 * 1024)
    do {
      while true {
        let count = Darwin.read(connection.descriptor, &bytes, bytes.count)
        if count > 0 {
          connection.input.append(contentsOf: bytes.prefix(count))
          guard connection.input.count <= ClaudeBridgeLimits.maximumFrameBytes + 4 else {
            throw ClaudeBridgeError.protocolViolation
          }
          while let message = try ClaudeBridgeWire.extract(from: &connection.input) {
            if connection.handshaken {
              try handle(message, connection: connection)
            } else {
              try handshake(message, connection: connection)
            }
          }
        } else if count < 0, errno == EINTR {
          continue
        } else if count < 0, errno == EAGAIN {
          return
        } else {
          throw ClaudeBridgeError.disconnected
        }
      }
    } catch { closeConnection(connection, reason: "disconnected") }
  }

  private func handshake(_ message: ClaudeBridgeMessage, connection: ClaudeBridgeConnection) throws {
    guard case .hello(let version, _) = message, version == ClaudeBridgeLimits.protocolVersion else {
      throw ClaudeBridgeError.protocolViolation
    }
    connection.handshaken = true
    try ClaudeBridgeWire.send(.hello(version: ClaudeBridgeLimits.protocolVersion, launchID: launchID), to: connection.descriptor)
  }

  private func handle(_ message: ClaudeBridgeMessage, connection: ClaudeBridgeConnection) throws {
    switch message {
    case .event(let event):
      guard connection.request == nil, valid(event.agent), event.originalInput.count <= ClaudeBridgeLimits.maximumInputBytes else {
        throw ClaudeBridgeError.protocolViolation
      }
      callback?(message)
    case .request(let request):
      try register(request, connection: connection)
    case .heartbeat(let id):
      guard connection.request?.id == id, !connection.accepted else { throw ClaudeBridgeError.protocolViolation }
      connection.heartbeat = ContinuousClock.now
      callback?(message)
    case .received(let id, let responseID):
      try acknowledge(id, responseID: responseID, connection: connection)
    case .cancelled(let id, let reason):
      guard connection.request?.id == id else { throw ClaudeBridgeError.protocolViolation }
      closeConnection(connection, reason: reason)
    default: throw ClaudeBridgeError.protocolViolation
    }
  }

  private func register(_ request: ClaudeRequest, connection: ClaudeBridgeConnection) throws {
    guard connection.request == nil, valid(request.id.agent), request.phase == .waiting,
      request.originalInput.count <= ClaudeBridgeLimits.maximumInputBytes,
      request.deadline > Date(), request.deadline.timeIntervalSinceNow <= Double(ClaudeBridgeLimits.requestLifetimeSeconds),
      !connections.values.contains(where: { $0.request?.id == request.id })
    else { throw ClaudeBridgeError.protocolViolation }
    connection.request = request
    connection.deadline = ContinuousClock.now.advanced(by: .seconds(request.deadline.timeIntervalSinceNow))
    callback?(.request(request))
  }

  private func acknowledge(_ id: ClaudeRequestID, responseID: UUID, connection: ClaudeBridgeConnection) throws {
    guard connection.request?.id == id, connection.responseID == responseID else { throw ClaudeBridgeError.protocolViolation }
    if !connection.accepted {
      connection.accepted = true
      acknowledged[id] = responseID
      if acknowledged.count > 256 { acknowledged.removeValue(forKey: acknowledged.keys.first!) }
      connection.completion?.resume()
      connection.completion = nil
      callback?(.received(requestID: id, responseID: responseID))
    }
  }

  private func checkDeadlines() {
    let now = ContinuousClock.now
    for connection in Array(connections.values) {
      if let deadline = connection.deadline {
        if deadline <= now {
          closeConnection(connection, reason: "expired")
        } else if connection.heartbeat.duration(to: now) > .seconds(35) {
          closeConnection(connection, reason: "heartbeat-lost")
        } else if let sent = connection.responseSentAt, !connection.accepted, sent.duration(to: now) > .seconds(5) {
          closeConnection(connection, reason: "acknowledgement-timeout")
        }
      } else if connection.opened.duration(to: now) > .seconds(2) {
        closeConnection(connection, reason: "idle")
      }
    }
  }

  private func closeConnection(_ connection: ClaudeBridgeConnection, reason: String) {
    guard connections.removeValue(forKey: connection.descriptor) != nil else { return }
    connection.completion?.resume(throwing: ClaudeBridgeError.disconnected)
    connection.completion = nil
    if let request = connection.request, !connection.accepted {
      callback?(.cancelled(requestID: request.id, reason: reason))
    }
    shutdown(connection.descriptor, SHUT_RDWR)
    connection.source.cancel()
  }

}

extension ClaudeBridgeSocket {
  private func stopOnQueue() {
    timer?.cancel()
    timer = nil
    for connection in Array(connections.values) { closeConnection(connection, reason: "module-disabled") }
    listenerSource?.cancel()
    listenerSource = nil
    if listener >= 0 {
      close(listener)
      listener = -1
    }
    if lock >= 0 {
      unlink(paths.socket.path)
      flock(lock, LOCK_UN)
      close(lock)
      lock = -1
    }
    acknowledged.removeAll()
    callback = nil
  }
}

private func valid(_ agent: ClaudeAgentID) -> Bool {
  agent.provider == "claude-code" && !agent.sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
