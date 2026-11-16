import Testing

@testable import IslandCore

struct LimitsNavigationTests {
  @Test("Навигация не содержит сессий и ответов агентов")
  func noAgentScreens() {
    let names = Set(ExpandedView.allCases.map(\.rawValue))
    #expect(names.isDisjoint(with: ["agents", "codexAgents", "inbox"]))
  }

  @Test("Лимиты возвращают в каталог модулей")
  func limitsBackTarget() {
    #expect(ExpandedView.claude.backTarget == .modules)
  }
}
