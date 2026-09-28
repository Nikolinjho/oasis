import IslandCore
import Testing
@testable import AlcoveAnalog

/// DebugScript.current — общий на процесс слот: параллельно тесты этого файла не гоняем,
/// иначе один прогон случайно отменяет чужой и тесты становятся редко-плавающими
@Suite(.serialized)
@MainActor
struct DebugScriptTests {
    @Test("Новый прогон отменяет предыдущий: шаги двух сценариев не перемешиваются")
    func overlappingRunsCancelPrevious() async throws {
        final class Log { var events: [String] = [] }
        let log = Log()
        DebugScript.run([(at: 0.05, run: { log.events.append("first") })])
        DebugScript.run([(at: 0.05, run: { log.events.append("second") })])
        try await Task.sleep(for: .milliseconds(200))
        #expect(log.events == ["second"])
    }

    @Test("Отмену прогона другим действием demo не оставляет store в .alcove: конфиг возвращается")
    func cancelledDemoRunRestoresConfig() async throws {
        let store = IslandStore(config: .user)
        DemoSequence.run(store: store)
        // любое отладочное действие или ссылка отменяет текущий DebugScript.run — не только другой demo
        DebugScript.run([])
        try await Task.sleep(for: .milliseconds(200))
        #expect(store.config == .user)
    }

    @Test("Двойной старт demo.run (второй поверх первого) в итоге тоже возвращает исходный конфиг")
    func doubleStartedDemoRunRestoresConfig() async throws {
        let store = IslandStore(config: .user)
        DemoSequence.run(store: store)
        DemoSequence.run(store: store)
        DebugScript.run([])
        try await Task.sleep(for: .milliseconds(200))
        #expect(store.config == .user)
    }
}
