import Darwin
import Foundation
import IslandCore

public enum ClaudeBridgeWire {
  public static func frame(_ message: ClaudeBridgeMessage) throws -> Data {
    let payload = try JSONEncoder().encode(message)
    guard payload.count <= ClaudeBridgeLimits.maximumFrameBytes else { throw ClaudeBridgeError.protocolViolation }
    var length = UInt32(payload.count).bigEndian
    var data = withUnsafeBytes(of: &length) { Data($0) }
    data.append(payload)
    return data
  }

  public static func extract(from buffer: inout Data) throws -> ClaudeBridgeMessage? {
    guard buffer.count >= 4 else { return nil }
    let length = buffer.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
    guard length > 0, length <= ClaudeBridgeLimits.maximumFrameBytes else { throw ClaudeBridgeError.protocolViolation }
    guard buffer.count >= length + 4 else { return nil }
    let payload = Data(buffer.dropFirst(4).prefix(length))
    buffer.removeFirst(length + 4)
    return try JSONDecoder().decode(ClaudeBridgeMessage.self, from: payload)
  }

  public static func configure(_ descriptor: Int32) throws {
    var enabled: Int32 = 1
    guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0,
      fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0,
      setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0
    else { throw ClaudeBridgeError.unavailable }
  }

  public static func sameUser(_ descriptor: Int32) -> Bool {
    var uid: uid_t = 0
    var gid: gid_t = 0
    return getpeereid(descriptor, &uid, &gid) == 0 && uid == getuid()
  }

  public static func connect(paths: ClaudeBridgePaths) throws -> Int32 {
    try paths.prepare()
    var info = stat()
    guard lstat(paths.socket.path, &info) == 0, info.st_mode & S_IFMT == S_IFSOCK,
      info.st_uid == getuid(), info.st_mode & 0o777 == 0o600
    else { throw ClaudeBridgeError.unavailable }
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw ClaudeBridgeError.unavailable }
    do {
      try configure(descriptor)
      var address = try paths.address()
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
      }
      if result != 0 {
        guard errno == EINPROGRESS else { throw ClaudeBridgeError.unavailable }
        try wait(descriptor, events: Int16(POLLOUT), milliseconds: 200)
        var error: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &size) == 0, error == 0 else {
          throw ClaudeBridgeError.unavailable
        }
      }
      guard sameUser(descriptor) else { throw ClaudeBridgeError.unavailable }
      return descriptor
    } catch {
      close(descriptor)
      throw error
    }
  }

  public static func wait(_ descriptor: Int32, events: Int16, milliseconds: Int32) throws {
    let deadline = ContinuousClock.now.advanced(by: .milliseconds(milliseconds))
    repeat {
      var descriptorInfo = pollfd(fd: descriptor, events: events, revents: 0)
      let result = poll(&descriptorInfo, 1, remainingMilliseconds(until: deadline))
      if result < 0, errno == EINTR { continue }
      guard result > 0, descriptorInfo.revents & events != 0 else { throw ClaudeBridgeError.disconnected }
      return
    } while ContinuousClock.now < deadline
    throw ClaudeBridgeError.disconnected
  }

  public static func remainingMilliseconds(until deadline: ContinuousClock.Instant) -> Int32 {
    let remaining = ContinuousClock.now.duration(to: deadline).components
    return Int32(clamping: max(1, remaining.seconds * 1000 + remaining.attoseconds / 1_000_000_000_000_000))
  }

  public static func send(_ message: ClaudeBridgeMessage, to descriptor: Int32, milliseconds: Int32 = 200) throws {
    let data = try frame(message)
    var offset = 0
    let deadline = ContinuousClock.now.advanced(by: .milliseconds(milliseconds))
    while offset < data.count {
      let count = data.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress!.advanced(by: offset), data.count - offset) }
      if count > 0 {
        offset += count
        continue
      }
      if count < 0, errno == EINTR { continue }
      guard count < 0, errno == EAGAIN, deadline > ContinuousClock.now else { throw ClaudeBridgeError.disconnected }
      try wait(descriptor, events: Int16(POLLOUT), milliseconds: remainingMilliseconds(until: deadline))
    }
  }
}
