import Darwin
import Foundation
import IslandCore
import IslandSources

final class ClaudeHookCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false
  func cancel() { lock.withLock { value = true } }
  var cancelled: Bool { lock.withLock { value } }
}

struct ClaudeHookClient {
  let paths: ClaudeBridgePaths
  let cancellation: ClaudeHookCancellation

  func run(_ input: ClaudeHookInput) throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(ClaudeBridgeLimits.requestLifetimeSeconds))
    let descriptor = try ClaudeBridgeWire.connect(paths: paths)
    defer { close(descriptor) }
    try ClaudeBridgeWire.send(.hello(version: ClaudeBridgeLimits.protocolVersion, launchID: UUID()), to: descriptor)
    var buffer = Data()
    guard
      case .hello(let version, let launchID) = try receive(
        descriptor, buffer: &buffer, deadline: ContinuousClock.now.advanced(by: .milliseconds(200))),
      version == ClaudeBridgeLimits.protocolVersion
    else { throw ClaudeBridgeError.protocolViolation }
    if let request = input.request {
      try ClaudeBridgeWire.send(.request(request), to: descriptor)
      do { try waitForAnswer(request, descriptor: descriptor, buffer: &buffer, launchID: launchID, deadline: deadline) } catch {
        try? ClaudeBridgeWire.send(
          .cancelled(requestID: request.id, reason: cancellation.cancelled ? "cancelled" : "fallback"), to: descriptor)
        throw error
      }
    } else {
      try ClaudeBridgeWire.send(.event(input.event), to: descriptor)
    }
  }

  private func waitForAnswer(
    _ request: ClaudeRequest, descriptor: Int32, buffer: inout Data, launchID: UUID, deadline: ContinuousClock.Instant
  ) throws {
    var heartbeat = ContinuousClock.now
    while deadline > ContinuousClock.now, !cancellation.cancelled {
      try sendHeartbeat(request.id, descriptor: descriptor, previous: &heartbeat)
      guard let message = try readMessage(descriptor, buffer: &buffer, milliseconds: 200) else { continue }
      switch message {
      case .response:
        if try deliver(message, request: request, descriptor: descriptor, deadline: deadline) {
          return
        }
      case .hello(_, let currentLaunch):
        guard currentLaunch == launchID else { throw ClaudeBridgeError.disconnected }
      case .received(let id, _):
        guard id == request.id else { throw ClaudeBridgeError.protocolViolation }
        return
      case .cancelled, .error: throw ClaudeBridgeError.disconnected
      default: throw ClaudeBridgeError.protocolViolation
      }
    }
    throw ClaudeBridgeError.expired
  }

  private func sendHeartbeat(_ id: ClaudeRequestID, descriptor: Int32, previous: inout ContinuousClock.Instant) throws {
    guard previous.duration(to: .now) >= .seconds(10) else { return }
    try ClaudeBridgeWire.send(.heartbeat(requestID: id), to: descriptor)
    previous = ContinuousClock.now
  }

  private func deliver(
    _ message: ClaudeBridgeMessage, request: ClaudeRequest, descriptor: Int32,
    deadline: ContinuousClock.Instant
  ) throws -> Bool {
    guard case .response(let requestID, let responseID, let answer) = message,
      requestID == request.id, deadline > ContinuousClock.now, !cancellation.cancelled
    else {
      throw ClaudeBridgeError.protocolViolation
    }
    let output: Data
    if request.acceptsTerminalAnswer {
      let data = try ClaudeHookOutput.data(for: answer, request: request, validateDeadline: false)
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      guard let hook = object?["hookSpecificOutput"] as? [String: Any],
        let input = hook["updatedInput"] as? [String: Any], let answers = input["answers"] as? [String: String]
      else { throw ClaudeBridgeError.invalidAnswer }
      output = try JSONSerialization.data(withJSONObject: ["responseID": responseID.uuidString, "answers": answers])
    } else {
      output = try ClaudeHookOutput.data(for: answer, request: request, validateDeadline: false)
    }
    try writeOutput(output, deadline: deadline)
    if request.acceptsTerminalAnswer { return false }
    try ClaudeBridgeWire.send(.received(requestID: request.id, responseID: responseID), to: descriptor)
    return true
  }

  func finish(_ completion: ClaudeQuestionCompletion) throws {
    let descriptor = try ClaudeBridgeWire.connect(paths: paths)
    defer { close(descriptor) }
    let deadline = ContinuousClock.now.advanced(by: .seconds(1))
    var buffer = Data()
    try ClaudeBridgeWire.send(.hello(version: ClaudeBridgeLimits.protocolVersion, launchID: UUID()), to: descriptor)
    guard case .hello(let version, _) = try receive(descriptor, buffer: &buffer, deadline: deadline),
      version == ClaudeBridgeLimits.protocolVersion
    else { throw ClaudeBridgeError.protocolViolation }
    try ClaudeBridgeWire.send(.questionFinished(completion), to: descriptor)
    guard case .questionFinished(let confirmed) = try receive(descriptor, buffer: &buffer, deadline: deadline), confirmed == completion
    else { throw ClaudeBridgeError.protocolViolation }
  }

  private func receive(_ descriptor: Int32, buffer: inout Data, deadline: ContinuousClock.Instant) throws -> ClaudeBridgeMessage {
    while deadline > ContinuousClock.now, !cancellation.cancelled {
      if let message = try readMessage(descriptor, buffer: &buffer, milliseconds: ClaudeBridgeWire.remainingMilliseconds(until: deadline)) {
        return message
      }
    }
    throw ClaudeBridgeError.disconnected
  }

  private func readMessage(_ descriptor: Int32, buffer: inout Data, milliseconds: Int32) throws -> ClaudeBridgeMessage? {
    if let message = try ClaudeBridgeWire.extract(from: &buffer) { return message }
    var info = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
    let result = poll(&info, 1, milliseconds)
    if result == 0 || result < 0 && errno == EINTR { return nil }
    guard result > 0, info.revents & Int16(POLLIN) != 0 else { throw ClaudeBridgeError.disconnected }
    var bytes = [UInt8](repeating: 0, count: 16 * 1024)
    let count = Darwin.read(descriptor, &bytes, bytes.count)
    if count < 0, errno == EAGAIN || errno == EINTR { return nil }
    guard count > 0, buffer.count + count <= ClaudeBridgeLimits.maximumFrameBytes + 4 else {
      throw ClaudeBridgeError.disconnected
    }
    buffer.append(contentsOf: bytes.prefix(count))
    return try ClaudeBridgeWire.extract(from: &buffer)
  }

  private func writeOutput(_ data: Data, deadline: ContinuousClock.Instant) throws {
    guard deadline > ContinuousClock.now, !cancellation.cancelled else { throw ClaudeBridgeError.expired }
    let flags = fcntl(STDOUT_FILENO, F_GETFL)
    guard flags >= 0, fcntl(STDOUT_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else { throw ClaudeBridgeError.disconnected }
    defer { _ = fcntl(STDOUT_FILENO, F_SETFL, flags) }
    var output = data
    output.append(0x0A)
    var offset = 0
    while offset < output.count {
      guard deadline > ContinuousClock.now, !cancellation.cancelled else { throw ClaudeBridgeError.expired }
      let count = output.withUnsafeBytes { Darwin.write(STDOUT_FILENO, $0.baseAddress!.advanced(by: offset), output.count - offset) }
      if count < 0, errno == EINTR { continue }
      if count < 0, errno == EAGAIN {
        var info = pollfd(fd: STDOUT_FILENO, events: Int16(POLLOUT), revents: 0)
        let result = poll(&info, 1, 200)
        if result == 0 || result < 0 && errno == EINTR { continue }
        guard result > 0, info.revents & Int16(POLLOUT) != 0 else { throw ClaudeBridgeError.disconnected }
        continue
      }
      guard count > 0 else { throw ClaudeBridgeError.disconnected }
      offset += count
    }
  }
}
