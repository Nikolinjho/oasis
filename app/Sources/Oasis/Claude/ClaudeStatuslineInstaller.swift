import Darwin
import Foundation
import IslandSources

/// Меняет настройки Claude Code только по явному действию пользователя.
struct ClaudeStatuslineInstaller {
  enum Status: Equatable {
    case notInstalled, installed
    case foreign(String)
    case invalid(String)
  }

  struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

  let home: URL
  let scriptSource: URL
  var configDirectory: URL?
  var supportDirectoryOverride: URL?

  init(home: URL, scriptSource: URL, configDirectory: URL? = nil, supportDirectory: URL? = nil) {
    self.home = home
    self.scriptSource = scriptSource
    self.configDirectory = configDirectory
    supportDirectoryOverride = supportDirectory
  }

  var settingsURL: URL {
    let environment = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : $0 }
    let directory =
      configDirectory ?? environment.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
      ?? home.appendingPathComponent(".claude", isDirectory: true)
    return directory.appendingPathComponent("settings.json")
  }
  var supportDirectory: URL { supportDirectoryOverride ?? ClaudeFiles.directory(home: home) }
  var backupURL: URL { supportDirectory.appendingPathComponent("claude-settings.oasis-backup") }
  var installedScript: URL { ClaudeFiles.statuslineScript(in: supportDirectory) }
  var configURL: URL { ClaudeFiles.statuslineConfig(in: supportDirectory) }
  var command: String { "'" + installedScript.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
  var hasConnectionRecord: Bool {
    FileManager.default.fileExists(atPath: configURL.path) || FileManager.default.fileExists(atPath: backupURL.path)
  }

  static var live: Self {
    Self(
      home: FileManager.default.homeDirectoryForCurrentUser,
      scriptSource: (Bundle.main.resourceURL ?? URL(fileURLWithPath: "/unavailable"))
        .appendingPathComponent("claude-statusline.py"))
  }

  func status() -> Status {
    do {
      return try status(in: object(read(settingsURL)))
    } catch let error as Failure {
      return .invalid(error.message)
    } catch {
      return .invalid("Не удалось прочитать настройки Claude Code")
    }
  }

  func install(text: Bool, preservePrevious: Bool = true) throws {
    let original = try read(settingsURL)
    var settings = try object(original)
    switch try status(in: settings) {
    case .invalid(let message): throw Failure(message: message)
    case .installed:
      try reconnect(text: text, preservePrevious: preservePrevious, expectedSettings: original)
      return
    case .foreign, .notInstalled: break
    }
    let fm = FileManager.default
    guard !fm.fileExists(atPath: backupURL.path), !fm.fileExists(atPath: configURL.path) else {
      throw Failure(message: "Осталась запись предыдущего подключения. Настройки оставлены без изменений")
    }
    let previous = settings["statusLine"] as? [String: Any]
    var config: [String: Any] = ["text": text, "originalExists": original != nil]
    if let previous { config["previous"] = previous }
    configureChain(&config, preservePrevious: preservePrevious)
    var statusLine = previous ?? [:]
    statusLine["type"] = "command"
    statusLine["command"] = command
    settings["statusLine"] = statusLine
    let installedSettings = try json(settings)
    try fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    try fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try copyScript()
    do {
      if let original { try atomicWrite(original, to: backupURL, permissions: 0o600) }
      try atomicWrite(json(config), to: configURL, permissions: 0o600)
      try atomicWrite(installedSettings, to: settingsURL, permissions: 0o600) {
        try requireUnchanged(settingsURL, expected: original)
      }
    } catch {
      try? fm.removeItem(at: backupURL)
      try? fm.removeItem(at: configURL)
      throw error
    }
  }

  func uninstall() throws {
    let current = try read(settingsURL)
    var settings = try object(current)
    guard try status(in: settings) == .installed else {
      guard hasConnectionRecord else { return }
      _ = try connectionConfiguration()
      try removeConnectionRecord()
      return
    }
    let config = try connectionConfiguration()
    let originallyExisted = config["originalExists"] as? Bool == true
    let backup = try read(backupURL)
    if originallyExisted, backup == nil { throw Failure(message: "Не найдена исходная копия настроек") }
    if let previous = config["previous"] { settings["statusLine"] = previous } else { settings.removeValue(forKey: "statusLine") }
    let backupSettings = try object(backup)
    if let backup, NSDictionary(dictionary: settings).isEqual(to: backupSettings) {
      try atomicWrite(backup, to: settingsURL, permissions: 0o600) {
        try requireUnchanged(settingsURL, expected: current)
      }
    } else if !originallyExisted, settings.isEmpty {
      try requireUnchanged(settingsURL, expected: current)
      try FileManager.default.removeItem(at: settingsURL)
    } else {
      try atomicWrite(json(settings), to: settingsURL, permissions: 0o600) {
        try requireUnchanged(settingsURL, expected: current)
      }
    }
    try removeConnectionRecord()
  }

  private func removeConnectionRecord() throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: backupURL.path) { try fm.removeItem(at: backupURL) }
    if fm.fileExists(atPath: configURL.path) { try fm.removeItem(at: configURL) }
  }

  func setText(_ text: Bool) throws {
    let settings = try read(settingsURL)
    guard try status(in: object(settings)) == .installed else { return }
    let original = try read(configURL)
    var config = try connectionConfiguration()
    guard config["text"] as? Bool != text else { return }
    config["text"] = text
    try atomicWrite(json(config), to: configURL, permissions: 0o600) {
      try requireUnchanged(settingsURL, expected: settings)
      try requireUnchanged(configURL, expected: original)
    }
  }

  private func reconnect(text: Bool, preservePrevious: Bool, expectedSettings: Data?) throws {
    let original = try read(configURL)
    var config = try connectionConfiguration()
    if config["originalExists"] as? Bool == true, try read(backupURL) == nil {
      throw Failure(message: "Не найдена исходная копия настроек")
    }
    config["text"] = text
    configureChain(&config, preservePrevious: preservePrevious)
    try requireUnchanged(settingsURL, expected: expectedSettings)
    try copyScript()
    try atomicWrite(json(config), to: configURL, permissions: 0o600) {
      try requireUnchanged(settingsURL, expected: expectedSettings)
      try requireUnchanged(configURL, expected: original)
    }
  }

  private func configureChain(_ config: inout [String: Any], preservePrevious: Bool) {
    config.removeValue(forKey: "chain")
    if preservePrevious, let previous = config["previous"] as? [String: Any],
      let previousCommand = previous["command"] as? String, previousCommand != command
    {
      config["chain"] = previousCommand
    }
  }

  private func connectionConfiguration() throws -> [String: Any] {
    guard let data = try read(configURL) else { throw Failure(message: "Не найдена запись подключения") }
    let config = try object(data)
    guard config["originalExists"] is Bool else { throw Failure(message: "Повреждена запись подключения") }
    if let previous = config["previous"] {
      guard let line = previous as? [String: Any], case .foreign = try status(in: ["statusLine": line]) else {
        throw Failure(message: "Повреждена запись прежнего statusline")
      }
    }
    return config
  }

  private func status(in settings: [String: Any]) throws -> Status {
    guard let raw = settings["statusLine"] else { return .notInstalled }
    guard let line = raw as? [String: Any], line["type"] as? String == "command",
      let value = line["command"] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw Failure(message: "Неподдерживаемый формат statusLine") }
    return value == command ? .installed : .foreign(value)
  }

  private func read(_ url: URL) throws -> Data? {
    do { return try Data(contentsOf: url) } catch CocoaError.fileReadNoSuchFile { return nil }
  }

  private func object(_ data: Data?) throws -> [String: Any] {
    guard let data else { return [:] }
    guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw Failure(message: "Настройки должны содержать JSON-объект")
    }
    return value
  }

  private func json(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
  }

  private func requireUnchanged(_ url: URL, expected: Data?) throws {
    guard try read(url) == expected else {
      throw Failure(message: "Настройки изменились во время подключения. Повтори действие")
    }
  }

  private func copyScript() throws {
    try atomicWrite(Data(contentsOf: scriptSource), to: installedScript, permissions: 0o700)
  }

  /// Создаёт временный файл с закрытыми правами до записи и проверяет исходник перед rename.
  private func atomicWrite(_ data: Data, to url: URL, permissions: mode_t, beforeRename: () throws -> Void = {}) throws {
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".oasis-\(UUID().uuidString).tmp")
    let fd = open(temporary.path, O_CREAT | O_EXCL | O_WRONLY, permissions)
    guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer {
      try? handle.close()
      try? FileManager.default.removeItem(at: temporary)
    }
    guard fchmod(fd, permissions) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    try handle.write(contentsOf: data)
    try handle.synchronize()
    try beforeRename()
    guard rename(temporary.path, url.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
  }
}
