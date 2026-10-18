import Foundation
import IslandCore

extension ClaudeRequestsModule {
  func refreshBranch(for agent: ClaudeAgentSnapshot) {
    guard !agent.directory.isEmpty, agent.id.agentID == nil || agent.parent != nil,
      branchDirectories[agent.id] != agent.directory || Date().timeIntervalSince(branchDates[agent.id] ?? .distantPast) > 30
    else { return }
    let id = agent.id
    let directory = agent.directory
    let current = generation
    branchDirectories[id] = directory
    branchDates[id] = Date()
    Task { [weak self] in
      let branch = await Task.detached(priority: .utility) { Self.readBranch(directory: directory) }.value
      guard let self, generation == current,
        let index = panel.agents.firstIndex(where: { $0.id == id && $0.directory == directory })
      else { return }
      panel.agents[index].branch = branch
      publish()
    }
  }

  nonisolated private static func readBranch(directory: String) -> String? {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["--no-optional-locks", "-C", directory, "rev-parse", "--abbrev-ref", "HEAD"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return nil }
      let branch = String(decoding: data.prefix(256), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
      return branch.isEmpty ? nil : branch
    } catch { return nil }
  }
}
