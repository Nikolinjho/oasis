import Testing
@testable import AlcoveAnalog

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
}
