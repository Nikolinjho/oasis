import Foundation
import IslandCore
import Testing

@testable import Oasis

@MainActor
struct ClaudeQuestionNavigationTests {
  private func module(multiSelect: Bool = false) -> (ClaudeRequestsModule, ClaudeRequest) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let module = ClaudeRequestsModule(
      store: IslandStore(), installer: .init(home: directory, helperSource: directory.appendingPathComponent("helper")))
    let request = ClaudeRequest(
      id: .init(agent: .init(sessionID: "test")), kind: .questions, toolName: "AskUserQuestion",
      originalInput: Data(),
      questions: [
        .init(text: "Первый", header: "Первый", options: [.init(label: "Да"), .init(label: "Нет")], multiSelect: multiSelect),
        .init(text: "Второй", header: "Второй", options: [.init(label: "Да")], multiSelect: false),
      ])
    module.panel.requests = [request]
    module.requestDeadlines[request.id] = .now.advanced(by: .seconds(60))
    return (module, request)
  }

  @Test("Одиночный выбор сразу открывает следующий вопрос, последний ответ ожидает отправки")
  func singleSelectionAdvances() {
    let (module, request) = module()
    module.perform(.toggleOption(request.id, question: 0, option: 0))
    #expect(module.panel.drafts[request.id]?.questionIndex == 1)
    module.perform(.toggleOption(request.id, question: 1, option: 0))
    #expect(module.panel.drafts[request.id]?.questionIndex == 1)
    #expect(module.panel.drafts[request.id]?.answer(for: request) != nil)
    #expect(module.panel.requests.first?.phase == .waiting)
  }

  @Test("Множественный выбор оставляет вопрос открытым для остальных вариантов")
  func multipleSelectionStays() {
    let (module, request) = module(multiSelect: true)
    module.perform(.toggleOption(request.id, question: 0, option: 0))
    module.perform(.toggleOption(request.id, question: 0, option: 1))
    #expect(module.panel.drafts[request.id]?.questionIndex == 0)
    #expect(module.panel.drafts[request.id]?.options[0] == [0, 1])
  }
}
