import CryptoKit
import Darwin
import Foundation
import IslandCore

/// Устанавливает только собственные hooks, сохраняя остальные настройки Claude.
struct ClaudeHooksInstaller {
  struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

  let home: URL
  let helperSource: URL
  var configDirectory: URL?

  static var live: Self {
    Self(
      home: FileManager.default.homeDirectoryForCurrentUser,
      helperSource: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OasisClaudeBridge"))
  }

  var settingsURL: URL {
    let environment = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : $0 }
    return
      (configDirectory ?? environment.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
      ?? home.appendingPathComponent(".claude")).appendingPathComponent("settings.json").standardizedFileURL
  }
  var directory: URL { home.appendingPathComponent("Library/Application Support/Oasis/ClaudeAgents") }
  var installedHelper: URL { directory.appendingPathComponent("OasisClaudeBridge") }
  var configurationKey: String { digest(Data(settingsURL.path.utf8)) }
  var manifestURL: URL { directory.appendingPathComponent("hooks-\(configurationKey).json") }
  var backupURL: URL { directory.appendingPathComponent("settings-before-hooks-\(configurationKey).json") }
  var command: String { "'" + installedHelper.path.replacingOccurrences(of: "'", with: "'\\''") + "' hook" }
  var hasConnectionRecord: Bool { FileManager.default.fileExists(atPath: manifestURL.path) }

  func isInstalled() throws -> Bool {
    guard hasConnectionRecord else { return false }
    try validateSupportDirectory()
    let manifest = try connectionRecord()
    guard manifest["state"] as? String == "installed",
      manifest["version"] as? Int == 3,
      manifest["protocolVersion"] as? Int == ClaudeBridgeLimits.protocolVersion,
      FileManager.default.isExecutableFile(atPath: installedHelper.path),
      let helper = try read(installedHelper),
      manifest["helperDigest"] as? String == digest(helper),
      digest(helper) == digest(try Data(contentsOf: helperSource))
    else { return false }
    let settings = try object(read(settingsURL))
    guard try questionPluginInstalled(manifest: manifest),
      (settings["enabledPlugins"] as? [String: Any])?[questionPluginID] as? Bool != false
    else { return false }
    let hooks = try validatedHooks(object(read(settingsURL)))
    try rejectModifiedOwnedHooks(hooks, owned: entries)
    return entries.allSatisfy { event, groups in
      guard let current = hooks[event] as? [[String: Any]] else { return false }
      return groups.allSatisfy { wanted in current.contains { containsOwned($0, wanted: wanted) } }
    }
  }

  func install() throws {
    try withConnectionLock {
      let original = try read(settingsURL)
      var settings = try object(original)
      var hooks = try validatedHooks(settings)
      if hasConnectionRecord, let owned = try connectionRecord()["entries"] as? [String: [[String: Any]]] {
        hooks = try removingOwnedHooks(from: hooks, owned: owned)
      }
      settings["hooks"] = try addingOwnedHooks(to: hooks)
      let helper = try Data(contentsOf: helperSource)
      var manifest = try installRecord(original: original, helper: helper)
      let pluginContents = try prepareQuestionPlugin(helper: helper, settings: &settings, manifest: &manifest)
      try atomicWrite(encode(manifest), to: manifestURL, permissions: 0o600)
      try installQuestionPlugin(pluginContents)
      try atomicWrite(helper, to: installedHelper, permissions: 0o700)
      try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try atomicWrite(encode(settings), to: settingsURL, permissions: 0o600) {
        try requireUnchanged(original)
      }
      manifest["state"] = "installed"
      manifest["entries"] = entries
      manifest.removeValue(forKey: "pluginAllowedDigests")
      try atomicWrite(encode(manifest), to: manifestURL, permissions: 0o600)
    }
  }

  func uninstall() throws {
    guard hasConnectionRecord else { return }
    try withConnectionLock {
      let manifest = try connectionRecord()
      guard let owned = manifest["entries"] as? [String: [[String: Any]]] else {
        throw Failure(message: "Повреждена запись подключения Claude")
      }
      let original = try read(settingsURL)
      var settings = try object(original)
      try validateQuestionPlugin(manifest: manifest)
      let hooks = try removingOwnedHooks(from: validatedHooks(settings), owned: owned)
      if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
      try restoreQuestionPluginSetting(settings: &settings, manifest: manifest)
      if original != nil {
        try atomicWrite(encode(settings), to: settingsURL, permissions: 0o600) {
          try requireUnchanged(original)
        }
      }
      if original == nil { try requireUnchanged(nil) }
      try removeQuestionPlugin(manifest: manifest)
      try FileManager.default.removeItem(at: manifestURL)
    }
  }

  func installRecord(original: Data?, helper: Data) throws -> [String: Any] {
    let previous: [String: Any]?
    if hasConnectionRecord {
      previous = try connectionRecord()
    } else if let original {
      try atomicWrite(original, to: backupURL, permissions: 0o600)
      previous = nil
    } else {
      previous = nil
    }
    var manifest: [String: Any] = [
      "version": 3, "settingsPath": settingsURL.path, "entries": entries, "state": "pending",
      "protocolVersion": ClaudeBridgeLimits.protocolVersion, "helperDigest": digest(helper),
    ]
    if let previous {
      for key in ["pluginDigests", "pluginEnabledBefore"] { manifest[key] = previous[key] }
      var owned = previous["entries"] as? [String: [[String: Any]]] ?? [:]
      for (event, groups) in entries { owned[event, default: []].append(contentsOf: groups) }
      manifest["entries"] = owned
    }
    return manifest
  }

  func connectionRecord() throws -> [String: Any] {
    let record = try object(read(manifestURL))
    guard record["settingsPath"] as? String == settingsURL.path,
      [2, 3].contains(record["version"] as? Int ?? 0),
      record["entries"] is [String: [[String: Any]]]
    else { throw Failure(message: "Повреждена запись подключения Claude") }
    return record
  }

  func requireUnchanged(_ original: Data?) throws {
    guard try read(settingsURL) == original else {
      throw Failure(message: "Настройки Claude изменились. Повтори действие")
    }
  }

  func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
