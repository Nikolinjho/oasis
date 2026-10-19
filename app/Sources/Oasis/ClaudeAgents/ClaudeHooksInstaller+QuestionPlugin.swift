import Darwin
import Foundation

extension ClaudeHooksInstaller {
  var questionPluginID: String { "oasis-questions@skills-dir" }
  var questionPluginDirectory: URL {
    settingsURL.deletingLastPathComponent().appendingPathComponent("skills/oasis-questions")
  }
  private var questionPluginOwnershipURL: URL { directory.appendingPathComponent("question-plugin-\(configurationKey).json") }
  private var questionPluginSource: URL { helperSource.deletingLastPathComponent().appendingPathComponent("ClaudeAgents") }
  private var questionPluginFiles: [String] {
    [".claude-plugin/plugin.json", "hooks/hooks.json", "hooks/register.js", "OasisClaudeBridge"]
  }

  func prepareQuestionPlugin(helper: Data, settings: inout [String: Any], manifest: inout [String: Any]) throws -> [String: Data] {
    var plugins = try enabledPlugins(settings)
    let previous = hasConnectionRecord ? try connectionRecord() : try questionPluginOwnership()
    try validateQuestionPlugin(manifest: previous)
    var contents: [String: Data] = [:]
    var digests: [String: String] = [:]
    var allowed = previous["pluginAllowedDigests"] as? [String: [String]] ?? [:]
    for (path, hash) in previous["pluginDigests"] as? [String: String] ?? [:] {
      allowed[path, default: []].append(hash)
    }
    for path in questionPluginFiles {
      let data = path == "OasisClaudeBridge" ? helper : try Data(contentsOf: questionPluginSource.appendingPathComponent(path))
      contents[path] = data
      digests[path] = digest(data)
    }
    if manifest["pluginEnabledBefore"] == nil { manifest["pluginEnabledBefore"] = plugins[questionPluginID] ?? NSNull() }
    manifest["pluginDigests"] = digests
    manifest["pluginAllowedDigests"] = allowed.mapValues { Array(Set($0)) }
    plugins[questionPluginID] = true
    settings["enabledPlugins"] = plugins
    return contents
  }

  func installQuestionPlugin(_ contents: [String: Data]) throws {
    try prepareQuestionPluginDirectory()
    for path in questionPluginFiles {
      guard let data = contents[path] else { throw Failure(message: "Неполный плагин Oasis") }
      let target = questionPluginDirectory.appendingPathComponent(path)
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      try atomicWrite(data, to: target, permissions: path == "OasisClaudeBridge" ? 0o700 : 0o600)
    }
  }

  func questionPluginInstalled(manifest: [String: Any]) throws -> Bool {
    guard let digests = manifest["pluginDigests"] as? [String: String], digests.count == questionPluginFiles.count else { return false }
    try validateQuestionPlugin(manifest: manifest)
    for path in questionPluginFiles {
      guard let data = try read(questionPluginDirectory.appendingPathComponent(path)), digest(data) == digests[path] else { return false }
      let expected = path == "OasisClaudeBridge" ? helperSource : questionPluginSource.appendingPathComponent(path)
      guard digest(data) == digest(try Data(contentsOf: expected)) else { return false }
    }
    return true
  }

  func validateQuestionPlugin(manifest: [String: Any]) throws {
    try validateQuestionPluginParents()
    guard let digests = manifest["pluginDigests"] as? [String: String] else {
      var info = stat()
      guard lstat(questionPluginDirectory.path, &info) != 0, errno == ENOENT else {
        throw Failure(message: "Каталог oasis-questions уже существует и не принадлежит этому подключению")
      }
      return
    }
    guard Set(digests.keys) == Set(questionPluginFiles) else { throw Failure(message: "Повреждена запись плагина Oasis") }
    let allowed = manifest["state"] as? String == "pending" ? manifest["pluginAllowedDigests"] as? [String: [String]] ?? [:] : [:]
    for path in questionPluginFiles {
      if let data = try read(questionPluginDirectory.appendingPathComponent(path)), digest(data) != digests[path],
        !allowed[path, default: []].contains(digest(data))
      {
        throw Failure(message: "Плагин Oasis изменён вручную. Восстанови его перед обновлением или отключением")
      }
    }
  }

  func restoreQuestionPluginSetting(settings: inout [String: Any], manifest: [String: Any]) throws {
    guard manifest["pluginDigests"] != nil else { return }
    var plugins = try enabledPlugins(settings)
    guard plugins[questionPluginID] as? Bool == true else { return }
    if let previous = manifest["pluginEnabledBefore"], !(previous is NSNull) {
      plugins[questionPluginID] = previous
    } else {
      plugins.removeValue(forKey: questionPluginID)
    }
    if plugins.isEmpty { settings.removeValue(forKey: "enabledPlugins") } else { settings["enabledPlugins"] = plugins }
  }

  func removeQuestionPlugin(manifest: [String: Any]) throws {
    guard manifest["pluginDigests"] != nil else { return }
    try atomicWrite(encode(manifest), to: questionPluginOwnershipURL, permissions: 0o600)
    for path in questionPluginFiles {
      let target = questionPluginDirectory.appendingPathComponent(path)
      if try read(target) != nil { try FileManager.default.removeItem(at: target) }
    }
    for path in [".claude-plugin", "hooks", ""] {
      let target = path.isEmpty ? questionPluginDirectory : questionPluginDirectory.appendingPathComponent(path)
      if let contents = try? FileManager.default.contentsOfDirectory(atPath: target.path), contents.isEmpty {
        try FileManager.default.removeItem(at: target)
      }
    }
  }

  private func questionPluginOwnership() throws -> [String: Any] {
    guard let data = try read(questionPluginOwnershipURL) else { return [:] }
    let record = try object(data)
    guard record["settingsPath"] as? String == settingsURL.path else { throw Failure(message: "Повреждена запись плагина Oasis") }
    return record
  }

  private func enabledPlugins(_ settings: [String: Any]) throws -> [String: Any] {
    guard let raw = settings["enabledPlugins"] else { return [:] }
    guard let plugins = raw as? [String: Any] else { throw Failure(message: "Неподдерживаемый формат enabledPlugins") }
    return plugins
  }

  private func prepareQuestionPluginDirectory() throws {
    try FileManager.default.createDirectory(
      at: questionPluginDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try validateQuestionPluginParents()
  }

  private func validateQuestionPluginParents() throws {
    let root = settingsURL.deletingLastPathComponent()
    for url in [
      root, root.appendingPathComponent("skills"), questionPluginDirectory,
      questionPluginDirectory.appendingPathComponent("hooks"), questionPluginDirectory.appendingPathComponent(".claude-plugin"),
    ] {
      var info = stat()
      if lstat(url.path, &info) != 0 {
        guard errno == ENOENT else { throw posixFailure() }
        continue
      }
      guard info.st_mode & S_IFMT == S_IFDIR, info.st_uid == getuid(), info.st_mode & 0o022 == 0 else {
        throw Failure(message: "Небезопасный каталог плагина Oasis")
      }
    }
  }
}
