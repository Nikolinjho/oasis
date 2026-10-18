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
      if heartbeat.duration(to: .now) >= .seconds(10) {
        try ClaudeBridgeWire.send(.heartbeat(requestID: request.id), to: descriptor)
        heartbeat = ContinuousClock.now
      }
      guard let message = try readMessage(descriptor, buffer: &buffer, milliseconds: 200) else { continue }
      switch message {
      case .response(let requestID, let responseID, let answer):
        guard requestID == request.id, deadline > ContinuousClock.now, !cancellation.cancelled else {
          throw ClaudeBridgeError.protocolViolation
        }
        let output = try ClaudeHookOutput.data(for: answer, request: request, validateDeadline: false)
        try writeOutput(output, deadline: deadline)
        try ClaudeBridgeWire.send(.received(requestID: request.id, responseID: responseID), to: descriptor)
        return
      case .hello(_, let currentLaunch):
        guard currentLaunch == launchID else { throw ClaudeBridgeError.disconnected }
      case .cancelled, .error: throw ClaudeBridgeError.disconnected
      default: throw ClaudeBridgeError.protocolViolation
      }
    }
    throw ClaudeBridgeError.expired
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
