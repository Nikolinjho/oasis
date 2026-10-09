import Darwin
import Foundation
import IslandCore

/// История наблюдений: изменившиеся окна и одно наблюдение неизменных окон в минуту.
public struct ClaudeHistory: Equatable, Sendable {
  public static let keep: TimeInterval = 8 * 86_400
  public private(set) var entries: [ClaudeLimits]

  public init(entries: [ClaudeLimits] = []) {
    self.entries = entries.filter { !$0.isEmpty }.sorted { $0.capturedAt < $1.capturedAt }
  }

  @discardableResult
  public mutating func record(_ limits: ClaudeLimits) -> Bool {
    guard !limits.isEmpty else { return false }
    if let last = entries.last {
      guard limits.capturedAt > last.capturedAt else { return false }
      if last.fiveHour == limits.fiveHour, last.sevenDay == limits.sevenDay,
        limits.capturedAt.timeIntervalSince(last.capturedAt) < 60
      {
        return false
      }
    }
    entries.append(limits)
    return true
  }

  public mutating func trim(now: Date) {
    entries.removeAll { $0.capturedAt > now.addingTimeInterval(60) || now.timeIntervalSince($0.capturedAt) > Self.keep }
    if entries.count > 20_000 { entries.removeFirst(entries.count - 20_000) }
  }

  public static func load(from url: URL, now: Date = Date(), trimming: Bool = true) -> ClaudeHistory {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return ClaudeHistory() }
    let entries = text.split(separator: "\n").compactMap { ClaudeLimits.parse(Data($0.utf8)) }
    var history = ClaudeHistory(entries: entries)
    if trimming { history.trim(now: now) }
    return history
  }

  public func write(to url: URL) throws {
    var data = Data()
    for entry in entries {
      data.append(entry.jsonData())
      data.append(0x0A)
    }
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".claude-history-\(UUID().uuidString).tmp")
    let fd = open(temporary.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
    guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer {
      try? handle.close()
      try? FileManager.default.removeItem(at: temporary)
    }
    guard fchmod(fd, 0o600) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    try handle.write(contentsOf: data)
    try handle.synchronize()
    guard rename(temporary.path, url.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
  }

  public static func append(_ limits: ClaudeLimits, to url: URL) throws {
    var history = load(from: url)
    if history.record(limits) {
      history.trim(now: Date())
      try history.write(to: url)
    }
  }
}
