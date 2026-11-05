import Foundation
import Testing

@testable import IslandCore

struct ClaudeReplyDraftTests {
  private func request(multiSelect: Bool = false) -> ClaudeRequest {
    ClaudeRequest(
      id: .init(agent: .init(sessionID: "test")), kind: .questions, toolName: "AskUserQuestion",
      originalInput: Data(),
      questions: [
        .init(text: "Первый вопрос", header: "Первый", options: [.init(label: "Да")], multiSelect: multiSelect),
        .init(text: "Второй вопрос", header: "Второй", options: [.init(label: "Нет")], multiSelect: false),
      ])
  }

  @Test("Выбор в первом вопросе позволяет перейти ко второму без отправки неполного пакета")
  func partialAnswer() {
    let request = request()
    var draft = ClaudeReplyDraft()
    draft.options[0] = [0]
    #expect(draft.hasAnswer(for: request, questionIndex: 0))
    #expect(!draft.hasAnswer(for: request, questionIndex: 1))
    #expect(draft.nextUnansweredQuestion(for: request) == 1)
    #expect(draft.answer(for: request) == nil)
  }

  @Test("После ответа на все вопросы отправляется весь пакет")
  func completeAnswer() {
    let request = request()
    var draft = ClaudeReplyDraft()
    draft.options[0] = [0]
    draft.texts[1] = "Свой ответ"
    #expect(draft.nextUnansweredQuestion(for: request) == nil)
    #expect(
      draft.answer(for: request)
        == .questions([
          .init(questionIndex: 0, selection: .options([0])),
          .init(questionIndex: 1, selection: .text("Свой ответ")),
        ]))
  }

  @Test("Пропущенный вопрос находится и перед текущим, пустой текст ответом не считается")
  func skippedQuestion() {
    let request = request()
    var draft = ClaudeReplyDraft()
    draft.questionIndex = 1
    draft.options[1] = [0]
    draft.texts[0] = "  \n"
    #expect(draft.nextUnansweredQuestion(for: request) == 0)
    #expect(!draft.hasAnswer(for: request, questionIndex: 0))
    #expect(!draft.hasAnswer(for: request, questionIndex: 2))
  }

  @Test("Недопустимый вариант не разблокирует переход к следующему вопросу")
  func invalidOption() {
    let request = request(multiSelect: true)
    var draft = ClaudeReplyDraft()
    draft.options[0] = [3]
    #expect(!draft.hasAnswer(for: request, questionIndex: 0))
    #expect(draft.nextUnansweredQuestion(for: request) == 0)
    #expect(draft.answer(for: request) == nil)
  }
}
