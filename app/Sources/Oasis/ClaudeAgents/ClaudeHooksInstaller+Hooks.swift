import Foundation

extension ClaudeHooksInstaller {
  var entries: [String: [[String: Any]]] {
    var result: [String: [[String: Any]]] = [:]
    let events = [
      "SessionStart", "UserPromptSubmit", "PostToolUse", "PostToolUseFailure", "Stop", "SessionEnd",
      "SubagentStart", "SubagentStop", "Notification", "PreToolUse", "PermissionRequest", "StopFailure",
    ]
    for event in events {
      var group: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 600]]]
      if event == "PreToolUse" { group["matcher"] = "AskUserQuestion" }
      result[event] = [group]
      if event == "PreToolUse" {
        result[event]?.append([
          "matcher": "^(?!AskUserQuestion$).+",
          "hooks": [["type": "command", "command": command, "timeout": 5]],
        ])
      }
    }
    return result
  }

  func hasForeignDecisionHooks() throws -> Bool {
    let hooks = try validatedHooks(object(read(settingsURL)))
    return ["PreToolUse", "PermissionRequest"].contains { event in
      (hooks[event] as? [[String: Any]] ?? []).contains { group in
        (group["hooks"] as? [[String: Any]] ?? []).contains { item in
          guard let value = item["command"] as? String else { return true }
          return value != command
        }
      }
    }
  }

  func validatedHooks(_ settings: [String: Any]) throws -> [String: Any] {
    guard let raw = settings["hooks"] else { return [:] }
    guard let hooks = raw as? [String: Any] else { throw Failure(message: "Неподдерживаемый формат hooks") }
    for (event, rawGroups) in hooks {
      guard let groups = rawGroups as? [[String: Any]],
        groups.allSatisfy({ $0["hooks"] is [[String: Any]] })
      else { throw Failure(message: "Неподдерживаемый hook \(event)") }
    }
    return hooks
  }

  func containsOwned(_ group: [String: Any], wanted: [String: Any]) -> Bool {
    guard group["matcher"] as? String == wanted["matcher"] as? String,
      let commands = group["hooks"] as? [[String: Any]],
      let own = wanted["hooks"] as? [[String: Any]]
    else { return false }
    return own.allSatisfy { expected in commands.contains { equal($0, expected) } }
  }

  func addingOwnedHooks(to hooks: [String: Any]) throws -> [String: Any] {
    try rejectModifiedOwnedHooks(hooks, owned: entries)
    var hooks = hooks
    for (event, groups) in entries {
      var current = hooks[event] as? [[String: Any]] ?? []
      for group in groups where !current.contains(where: { containsOwned($0, wanted: group) }) {
        current.append(group)
      }
      hooks[event] = current
    }
    return hooks
  }

  func removingOwnedHooks(from hooks: [String: Any], owned: [String: [[String: Any]]]) throws -> [String: Any] {
    try rejectModifiedOwnedHooks(hooks, owned: owned)
    var hooks = hooks
    for (event, groups) in owned {
      guard let current = hooks[event] as? [[String: Any]] else { continue }
      let retained = current.compactMap { removingCommands(from: $0, owned: groups) }
      if retained.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = retained }
    }
    return hooks
  }

  func removingCommands(from group: [String: Any], owned: [[String: Any]]) -> [String: Any]? {
    var group = group
    let commands = group["hooks"] as? [[String: Any]] ?? []
    let matching = owned.filter { $0["matcher"] as? String == group["matcher"] as? String }
    let own = matching.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
    let remaining = commands.filter { item in !own.contains { equal(item, $0) } }
    guard remaining.count != commands.count else { return group }
    guard !remaining.isEmpty else { return nil }
    group["hooks"] = remaining
    return group
  }

  func rejectModifiedOwnedHooks(_ hooks: [String: Any], owned: [String: [[String: Any]]]) throws {
    for (event, rawGroups) in hooks {
      for group in rawGroups as? [[String: Any]] ?? [] {
        try validateOwnedCommands(group, owned: owned[event] ?? [])
      }
    }
  }

  func validateOwnedCommands(_ group: [String: Any], owned: [[String: Any]]) throws {
    let expected = owned.filter { $0["matcher"] as? String == group["matcher"] as? String }
      .flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
    for item in group["hooks"] as? [[String: Any]] ?? [] {
      guard let value = item["command"] as? String, value.contains(installedHelper.path) else { continue }
      guard expected.contains(where: { equal(item, $0) }) else {
        throw Failure(message: "Hook Oasis изменён вручную. Восстанови его перед подключением или отключением")
      }
    }
  }

  func equal(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
    NSDictionary(dictionary: lhs).isEqual(to: rhs)
  }
}
