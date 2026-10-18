import Foundation
import IslandCore

public enum ClaudeHookOutput {
  public static func data(for answer: ClaudeAnswer, request: ClaudeRequest, validateDeadline: Bool = true) throws -> Data {
    guard !validateDeadline || request.deadline > Date(), request.originalInput.count <= ClaudeBridgeLimits.maximumInputBytes,
      let input = try JSONSerialization.jsonObject(with: request.originalInput) as? [String: Any]
    else { throw ClaudeBridgeError.invalidAnswer }
    let output =
      try request.kind == .permission
      ? permission(answer, input: input) : questions(answer, request: request, input: input)
    return try JSONSerialization.data(withJSONObject: ["hookSpecificOutput": output], options: [.sortedKeys])
  }

  private static func permission(_ answer: ClaudeAnswer, input: [String: Any]) throws -> [String: Any] {
    guard input["hook_event_name"] as? String == "PermissionRequest" else { throw ClaudeBridgeError.invalidAnswer }
    var decision: [String: Any]
    switch answer {
    case .allowOnce: decision = ["behavior": "allow"]
    case .deny(let message):
      decision = ["behavior": "deny"]
      if let message { decision["message"] = message }
    case .questions: throw ClaudeBridgeError.invalidAnswer
    }
    return ["hookEventName": "PermissionRequest", "decision": decision]
  }

  private static func questions(_ answer: ClaudeAnswer, request: ClaudeRequest, input: [String: Any]) throws -> [String: Any] {
    guard input["hook_event_name"] as? String == "PreToolUse",
      input["tool_name"] as? String == "AskUserQuestion",
      var toolInput = input["tool_input"] as? [String: Any],
      case .questions(let answers) = answer, !request.questions.isEmpty,
      answers.count == request.questions.count,
      Set(request.questions.map(\.text)).count == request.questions.count,
      Set(answers.map(\.questionIndex)).count == answers.count
    else { throw ClaudeBridgeError.invalidAnswer }
    var mapped: [String: String] = [:]
    for answer in answers {
      guard request.questions.indices.contains(answer.questionIndex) else { throw ClaudeBridgeError.invalidAnswer }
      let question = request.questions[answer.questionIndex]
      mapped[question.text] = try value(answer.selection, question: question)
    }
    toolInput["answers"] = mapped
    return ["hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": toolInput]
  }

  private static func value(_ selection: ClaudeQuestionAnswer.Selection, question: ClaudeQuestion) throws -> String {
    switch selection {
    case .text(let text):
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ClaudeBridgeError.invalidAnswer }
      return text
    case .options(let indices):
      guard !indices.isEmpty, Set(indices).count == indices.count,
        question.multiSelect || indices.count == 1,
        indices.allSatisfy({ question.options.indices.contains($0) })
      else { throw ClaudeBridgeError.invalidAnswer }
      return indices.map { question.options[$0].label }.joined(separator: ", ")
    }
  }
}
