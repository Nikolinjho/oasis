import Foundation
import IslandCore
import Testing

@testable import Oasis

@Suite(.serialized)
@MainActor
struct CodexLimitsModuleTests {
  func limits(_ used: Int, at now: Date) -> CodexLimits {
    let data = Data(
      """
      {"rateLimits":{"limitId":"codex","primary":{"usedPercent":\(used),"windowDurationMins":300,"resetsAt":2000000000}}}
      """.utf8)
    return CodexLimits.parse(data, now: now)!
  }

  @Test("Скрытый раскрытый вид оставляет предупреждения, выключенный модуль отзывает их")
  func independentExpandedView() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let store = IslandStore()
    let module = CodexLimitsModule(store: store, defaults: defaults)
    module.settings.expandedView = false
    let now = Date()
    module.receive(.limits(limits(40, at: now)), now: now)
    module.receive(.limits(limits(96, at: now.addingTimeInterval(60))), now: now.addingTimeInterval(60))
    #expect(store.codexPanel == nil)
    #expect(store.attentionItems.contains { if case .alert(.codex) = $0.source { true } else { false } })
    module.settings.enabled = false
    module.applySettings()
    #expect(store.model.alertQueue.allSatisfy { $0.kind != .codex })
    if case .alert(let alert) = store.model.surface { #expect(alert.kind != .codex) }
  }
  @Test("Настройки вида и прогноза сохраняют показанное предупреждение, отключение предупреждений отзывает его")
  func presentationPreservesWarning() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let store = IslandStore()
    let module = CodexLimitsModule(store: store, defaults: defaults)
    let now = Date().addingTimeInterval(-120)
    module.receive(.limits(limits(40, at: now)), now: now)
    module.receive(.limits(limits(96, at: now.addingTimeInterval(60))), now: now.addingTimeInterval(60))
    let warning = store.model.surface
    if case .alert(let alert) = warning { #expect(alert.kind == .codex) } else { Issue.record("Ожидался peek Codex") }
    module.settings.expandedView = false
    module.settings.forecastUntilWorkday = true
    module.settings.criticalSound = false
    #expect(store.model.surface == warning)
    #expect(store.codexPanel == nil)
    module.settings.sessionWarning = false
    if case .alert(let alert) = store.model.surface { #expect(alert.kind != .codex) }
  }

}
