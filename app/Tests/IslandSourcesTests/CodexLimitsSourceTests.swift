import Foundation
import Testing

@testable import IslandSources

@MainActor
struct CodexLimitsSourceTests {
  @Test("Источник инициализируется и запрашивает только лимиты")
  func requestsOnlyLimits() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let executable = directory.appendingPathComponent("codex")
    let script = #"""
      #!/usr/bin/python3
      import json, sys
      assert json.loads(sys.stdin.readline())["method"] == "initialize"
      print('{"id":1,"result":{}}', flush=True)
      assert json.loads(sys.stdin.readline())["method"] == "initialized"
      assert json.loads(sys.stdin.readline())["method"] == "account/rateLimits/read"
      print('{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":47,"windowDurationMins":10080}}}}', flush=True)
      for line in sys.stdin:
          assert json.loads(line)["method"] == "account/rateLimits/read"
      """#
    try Data(script.utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    let source = CodexLimitsSource(executable: executable)
    defer { source.stop() }
    var remaining: Int?
    source.start { update in
      if case .limits(let limits) = update { remaining = limits.buckets.first?.windows.first?.remaining }
    }
    for _ in 0..<100 where remaining == nil { try await Task.sleep(for: .milliseconds(20)) }
    #expect(remaining == 53)
  }

  @Test("Недоступный Codex даёт причину вместо исчезновения раздела")
  func missingExecutable() {
    let source = CodexLimitsSource(executable: URL(fileURLWithPath: "/nonexistent/oasis-codex-test"))
    defer { source.stop() }
    var message: String?
    source.start { update in if case .unavailable(let reason) = update { message = reason } }
    #expect(message == "Не удалось запустить Codex CLI.")
  }
}
