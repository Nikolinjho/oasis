import AppKit
import Darwin
import Foundation

public struct SystemYandexLifecycle: YandexLifecycle {
  public init() {}
  public func appURL() async -> URL? {
    await MainActor.run { NSWorkspace.shared.urlForApplication(withBundleIdentifier: YandexMusicClient.bundleID) }
  }
  public func runningPIDs() async -> [Int32] {
    await MainActor.run {
      NSRunningApplication.runningApplications(withBundleIdentifier: YandexMusicClient.bundleID).filter { !$0.isTerminated }.map(
        \.processIdentifier)
    }
  }
  public func isRunning(_ pid: Int32) async -> Bool {
    await MainActor.run {
      NSRunningApplication(processIdentifier: pid).map { !$0.isTerminated && $0.bundleIdentifier == YandexMusicClient.bundleID } ?? false
    }
  }
  public func terminate(_ pid: Int32) async throws {
    let accepted = await MainActor.run {
      guard let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier == YandexMusicClient.bundleID else { return true }
      return app.terminate()
    }
    if !accepted { throw YandexClientError.terminationTimeout }
  }
  public func launch(_ app: URL, arguments: [String]) async throws -> Int32 {
    try await Self.open(app, arguments: arguments)
  }
  @MainActor private static func open(_ app: URL, arguments: [String]) async throws -> Int32 {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.arguments = arguments
    configuration.createsNewApplicationInstance = true
    let running = try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
    guard running.bundleIdentifier == YandexMusicClient.bundleID else { throw YandexClientError.unsafeEndpoint }
    return running.processIdentifier
  }
  public func freePort() async throws -> Int {
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw YandexClientError.busyPort }
    defer { Darwin.close(descriptor) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    let bound = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    guard bound == 0 else { throw YandexClientError.busyPort }
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let result = withUnsafeMutablePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
    }
    guard result == 0 else { throw YandexClientError.busyPort }
    return Int(UInt16(bigEndian: address.sin_port))
  }
  public func listeners(port: Int) async throws -> [YandexListener] {
    guard (1...65535).contains(port) else { throw YandexClientError.unsafeEndpoint }
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-Fpn"]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 || process.terminationStatus == 1 else { throw YandexClientError.unsafeEndpoint }
    var pid: Int32?
    var listeners: [YandexListener] = []
    for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
      if line.first == "p" {
        pid = Int32(line.dropFirst())
      } else if line.first == "n", let pid {
        listeners.append(YandexListener(pid: pid, address: String(line.dropFirst())))
      }
    }
    return listeners
  }
}
