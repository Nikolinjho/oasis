import Darwin
import Foundation
import IslandCore
import IslandSources

struct ClaudeHookInput {
  let event: ClaudeBridgeEvent
  let request: ClaudeRequest?

  init(data: Data, acceptsTerminalAnswer: Bool = false) throws {
    guard data.count <= ClaudeBridgeLimits.maximumInputBytes,
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let session = object["session_id"] as? String, !session.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let name = object["hook_event_name"] as? String
    else { throw ClaudeBridgeError.protocolViolation }
    let agent = ClaudeAgentID(sessionID: session, agentID: object["agent_id"] as? String)
    event = ClaudeBridgeEvent(agent: agent, eventName: name, originalInput: data)
    let tool = object["tool_name"] as? String ?? ""
    if name == "PermissionRequest", !tool.isEmpty, tool != "AskUserQuestion" {
      guard object["tool_input"] is [String: Any] else { throw ClaudeBridgeError.protocolViolation }
      request = ClaudeRequest(
        id: ClaudeRequestID(agent: agent), kind: .permission, toolName: tool,
        toolUseID: object["tool_use_id"] as? String, originalInput: data
      )
    } else if name == "PreToolUse", tool == "AskUserQuestion" {
      guard let input = object["tool_input"] as? [String: Any],
        let rawQuestions = input["questions"] as? [[String: Any]], !rawQuestions.isEmpty,
        rawQuestions.count <= 16
      else { throw ClaudeBridgeError.protocolViolation }
      let questions = try rawQuestions.map { item -> ClaudeQuestion in
        guard let text = item["question"] as? String, !text.isEmpty,
          let options = item["options"] as? [[String: Any]], !options.isEmpty, options.count <= 64
        else { throw ClaudeBridgeError.protocolViolation }
        let parsedOptions = try options.map { option -> ClaudeQuestion.Option in
          guard let label = option["label"] as? String, !label.isEmpty else { throw ClaudeBridgeError.protocolViolation }
          return ClaudeQuestion.Option(label: label, description: option["description"] as? String ?? "")
        }
        return ClaudeQuestion(
          text: text, header: item["header"] as? String ?? "", options: parsedOptions,
          multiSelect: item["multiSelect"] as? Bool ?? false
        )
      }
      guard Set(questions.map(\.text)).count == questions.count else { throw ClaudeBridgeError.protocolViolation }
      request = ClaudeRequest(
        id: ClaudeRequestID(agent: agent), kind: .questions, toolName: tool,
        toolUseID: object["tool_use_id"] as? String, originalInput: data, questions: questions,
        acceptsTerminalAnswer: acceptsTerminalAnswer
      )
    } else {
      let supported: Set<String> = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "Stop", "StopFailure", "SessionEnd", "SubagentStart", "SubagentStop", "Notification",
      ]
      guard supported.contains(name) else { throw ClaudeBridgeError.protocolViolation }
      request = nil
    }
  }

  static func read(cancellation: ClaudeHookCancellation) throws -> ClaudeHookInput {
    try ClaudeHookInput(data: readData(cancellation: cancellation))
  }

  static func readData(cancellation: ClaudeHookCancellation) throws -> Data {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    let flags = fcntl(STDIN_FILENO, F_GETFL)
    guard flags >= 0, fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else { throw ClaudeBridgeError.disconnected }
    defer { _ = fcntl(STDIN_FILENO, F_SETFL, flags) }
    var data = Data()
    var chunk = [UInt8](repeating: 0, count: 16 * 1024)
    while deadline > ContinuousClock.now, !cancellation.cancelled {
      try waitForInput(deadline: deadline)
      let count = Darwin.read(STDIN_FILENO, &chunk, chunk.count)
      if count == 0 {
        guard !cancellation.cancelled else { throw ClaudeBridgeError.disconnected }
        return data
      }
      if count < 0, errno == EINTR || errno == EAGAIN { continue }
      guard count > 0, data.count + count <= ClaudeBridgeLimits.maximumInputBytes else {
        throw ClaudeBridgeError.protocolViolation
      }
      data.append(contentsOf: chunk.prefix(count))
    }
    throw ClaudeBridgeError.expired
  }

  private static func waitForInput(deadline: ContinuousClock.Instant) throws {
    var info = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    let result = poll(&info, 1, min(200, ClaudeBridgeWire.remainingMilliseconds(until: deadline)))
    if result == 0 || result < 0 && errno == EINTR { return }
    guard result > 0, info.revents & Int16(POLLIN | POLLHUP) != 0 else { throw ClaudeBridgeError.disconnected }
  }
}
