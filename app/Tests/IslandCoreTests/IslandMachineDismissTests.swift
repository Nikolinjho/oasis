import Testing
@testable import IslandCore

/// Свайп по компакту (General → Gestures → Swipe to dismiss activity): режим Alcove, темп 1
struct IslandMachineDismissTests {
    static func compact() -> IslandModel {
        var model = IslandModel(config: .alcove)
        model.surface = .compact
        model.hasMedia = true
        model.isPlaying = true
        return model
    }

    @Test("Свайп вверх убирает компакт в форму выреза, свайп вниз возвращает")
    func dismissAndRestore() {
        var m = Self.compact()
        #expect(IslandMachine.reduce(&m, .activityDismissed) == [.animate(.compactOut)])
        #expect(m.surface == .idle && m.base == .idle)
        #expect(IslandMachine.reduce(&m, .activityRestored) == [.animate(.compactIn)])
        #expect(m.surface == .compact)
        #expect(IslandMachine.reduce(&m, .activityRestored).isEmpty)
    }

    @Test("Peek убирается сразу, его таймер снят")
    func dismissPeek() {
        var m = Self.compact()
        m.surface = .peek
        #expect(IslandMachine.reduce(&m, .activityDismissed) == [.cancel(.peekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
    }

    @Test("В покое без активности убирать нечего")
    func nothingToDismiss() {
        var m = IslandModel(config: .alcove)
        #expect(IslandMachine.reduce(&m, .activityDismissed).isEmpty)
    }

    @Test("Новый трек, окно календаря и уведомление возвращают убранную активность")
    func comesBack() {
        var track = Self.compact()
        _ = IslandMachine.reduce(&track, .activityDismissed)
        #expect(IslandMachine.reduce(&track, .trackChanged) == [.animate(.compactIn)])
        #expect(track.surface == .compact)

        var calendar = Self.compact()
        _ = IslandMachine.reduce(&calendar, .activityDismissed)
        _ = IslandMachine.reduce(&calendar, .calendarLiveChanged(true))
        #expect(calendar.surface == .calendar)

        var alert = Self.compact()
        _ = IslandMachine.reduce(&alert, .activityDismissed)
        _ = IslandMachine.reduce(&alert, .alertArrived(.charging(level: 0.5)))
        #expect(!alert.dismissed)
        #expect(alert.base == .compact)
    }
}
