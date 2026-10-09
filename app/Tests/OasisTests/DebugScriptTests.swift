import IslandCore
import Testing

@testable import Oasis

/// DebugScript.current — общий на процесс слот: параллельно тесты этого файла не гоняем,
/// иначе один прогон случайно отменяет чужой и тесты становятся редко-плавающими
@Suite(.serialized)
@MainActor
struct DebugScriptTests {
  @Test("Новый прогон отменяет предыдущий: шаги двух сценариев не перемешиваются")
  func overlappingRunsCancelPrevious() async throws {
    final class Log { var events: [String] = [] }
    let log = Log()
    let first = DebugScript.run([(at: 0.05, run: { log.events.append("first") })])
    let second = DebugScript.run([(at: 0.05, run: { log.events.append("second") })])
    await first.value
    await second.value
    #expect(log.events == ["second"])
  }

  @Test("Отмену прогона другим действием demo не оставляет store в .alcove: конфиг возвращается")
  func cancelledDemoRunRestoresConfig() async throws {
    let store = IslandStore(config: .user)
    DemoSequence.run(store: store)
    try await Task.sleep(for: .milliseconds(50))
    #expect(store.config == .alcove)
    // любое отладочное действие или ссылка отменяет текущий DebugScript.run — не только другой demo
    DebugScript.run([])
    try await Task.sleep(for: .milliseconds(50))
    #expect(store.config == .user)
  }

  @Test("tuning.width показывает подложку сразу и снимает её через ~2 с (Task 17t)")
  func tuningWidthActionShowsThenReleases() async throws {
    let store = IslandStore(config: .alcove)
    let action = try #require(DebugCatalogTests.actions(store).first { $0.id == "tuning.width" })
    action.run()
    // первый шаг сценария (at: 0) всё равно выполняется в Task — синхронно сразу после run() его ещё нет
    try await Task.sleep(for: .milliseconds(50))
    #expect(store.model.surface == .tuning(.width(-1)))
    try await Task.sleep(for: .milliseconds(2200))
    #expect(store.model.surface == .idle)
  }

  @Test("Двойной старт demo.run (второй поверх первого) в итоге тоже возвращает исходный конфиг")
  func doubleStartedDemoRunRestoresConfig() async throws {
    let store = IslandStore(config: .user)
    DemoSequence.run(store: store)
    try await Task.sleep(for: .milliseconds(50))
    DemoSequence.run(store: store)
    try await Task.sleep(for: .milliseconds(50))
    // отменённый первый прогон не должен откатить раньше времени: второй ещё владеет конфигом
    #expect(store.config == .alcove)
    DebugScript.run([])
    try await Task.sleep(for: .milliseconds(50))
    #expect(store.config == .user)
  }
}
