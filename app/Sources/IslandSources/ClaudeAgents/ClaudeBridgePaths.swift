import Darwin
import Foundation

public enum ClaudeBridgeError: Error, Sendable {
  case unsafePath, unavailable, protocolViolation, disconnected, expired, invalidAnswer, busy
}

public struct ClaudeBridgePaths: Sendable {
  public let directory: URL
  public var socket: URL { directory.appendingPathComponent("ipc") }
  public var lock: URL { directory.appendingPathComponent("server.lock") }

  public init(directory: URL? = nil) {
    self.directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("oasis-claude", isDirectory: true)
  }

  public func prepare() throws {
    let parent = directory.deletingLastPathComponent()
    var info = stat()
    guard lstat(parent.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
      info.st_uid == getuid(), info.st_mode & 0o022 == 0
    else { throw ClaudeBridgeError.unsafePath }
    if mkdir(directory.path, 0o700) != 0, errno != EEXIST { throw ClaudeBridgeError.unsafePath }
    guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
      info.st_uid == getuid(), info.st_mode & 0o777 == 0o700
    else { throw ClaudeBridgeError.unsafePath }
    guard socket.path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
      throw ClaudeBridgeError.unsafePath
    }
  }

  public func address() throws -> sockaddr_un {
    guard socket.path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
      throw ClaudeBridgeError.unsafePath
    }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { bytes in
      bytes.copyBytes(from: Array(socket.path.utf8) + [0])
    }
    return address
  }
}
