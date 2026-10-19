import Darwin
import Foundation
import IslandCore
import IslandSources
import Security

let arguments = CommandLine.arguments.dropFirst()
let paths = ClaudeBridgePaths()
if arguments.first == "doctor" {
  let connected: Bool
  if let descriptor = try? ClaudeBridgeWire.connect(paths: paths) {
    close(descriptor)
    connected = true
  } else {
    connected = false
  }
  print(
    "OasisClaudeBridge protocol=\(ClaudeBridgeLimits.protocolVersion) socket=\(connected ? "available" : "unavailable") "
      + "signature=\(ClaudeBridgeDoctor.signature()) configOwnership=\(ClaudeBridgeDoctor.configOwnership())")
} else if ["hook", "question", "question-finished"].contains(arguments.first) {
  signal(SIGPIPE, SIG_IGN)
  signal(SIGTERM, SIG_IGN)
  signal(SIGINT, SIG_IGN)
  let cancellation = ClaudeHookCancellation()
  let sources = [SIGTERM, SIGINT].map { number in
    let source = DispatchSource.makeSignalSource(signal: number, queue: .global(qos: .userInitiated))
    source.setEventHandler { cancellation.cancel() }
    source.resume()
    return source
  }
  do {
    let data = try ClaudeHookInput.readData(cancellation: cancellation)
    let client = ClaudeHookClient(paths: paths, cancellation: cancellation)
    if arguments.first == "question-finished" {
      try client.finish(JSONDecoder().decode(ClaudeQuestionCompletion.self, from: data))
      print("confirmed")
    } else {
      let input = try ClaudeHookInput(data: data, acceptsTerminalAnswer: arguments.first == "question")
      try client.run(input)
    }
  } catch {
    // Ошибка моста возвращает управление штатному диалогу Claude без решения.
  }
  withExtendedLifetime(sources) {}
}

private enum ClaudeBridgeDoctor {
  static func signature() -> String {
    var code: SecCode?
    var staticCode: SecStaticCode?
    guard SecCodeCopySelf(SecCSFlags(rawValue: 0), &code) == errSecSuccess, let code,
      SecCodeCopyStaticCode(code, SecCSFlags(rawValue: 0), &staticCode) == errSecSuccess, let staticCode
    else { return "unavailable" }
    let status = SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSStrictValidate), nil)
    if status == errSecCSUnsigned { return "unsigned" }
    guard status == errSecSuccess else { return "invalid" }
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
      let details = information as? [String: Any]
    else { return "valid" }
    let certificates = details[kSecCodeInfoCertificates as String] as? [SecCertificate] ?? []
    return certificates.isEmpty ? "valid-adhoc" : "valid-signed"
  }

  static func configOwnership() -> String {
    let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : $0 }
    let directory =
      configured.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    var info = stat()
    guard lstat(directory.path, &info) == 0 else { return errno == ENOENT ? "missing" : "unavailable" }
    guard info.st_mode & S_IFMT == S_IFDIR else { return "unsafe" }
    guard info.st_uid == getuid() else { return "foreign" }
    guard info.st_mode & 0o022 == 0 else { return "unsafe" }
    guard lstat(directory.appendingPathComponent("settings.json").path, &info) == 0 else {
      return errno == ENOENT ? "missing" : "unavailable"
    }
    guard info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o022 == 0 else { return "unsafe" }
    return info.st_uid == getuid() ? "owned" : "foreign"
  }
}
