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

    @Test("Компакт календаря убирается в вырез так же, как компакт музыки")
    func dismissCalendar() {
        var m = IslandModel(config: .alcove)
        m.calendarLive = true
        m.surface = .calendar
        #expect(IslandMachine.reduce(&m, .activityDismissed) == [.animate(.compactOut)])
        #expect(m.surface == .idle && m.base == .idle)
    }

    @Test("Peek календаря убирается сразу, его таймер снят")
    func dismissCalendarPeek() {
        var m = IslandModel(config: .alcove)
        m.calendarLive = true
        m.surface = .calendarPeek
        #expect(IslandMachine.reduce(&m, .activityDismissed) == [.cancel(.calendarPeekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
    }

    @Test("Отклик hover без активности под ним не разворачивается уборкой: убирать нечего")
    func dismissHoverNudgeWithNothingToDismiss() {
        var m = IslandModel(config: .alcove)
        m.surface = .hoverNudge(from: .idle)
        #expect(IslandMachine.reduce(&m, .activityDismissed).isEmpty)
        #expect(m.surface == .hoverNudge(from: .idle))
    }

    @Test("Восстановление разворачивает отклик hover, как и уборка")
    func restoreUnwindsHoverNudge() {
        var m = Self.compact()
        _ = IslandMachine.reduce(&m, .activityDismissed)
        #expect(m.surface == .idle)
        m.surface = .hoverNudge(from: .idle)
        #expect(IslandMachine.reduce(&m, .activityRestored) == [.cancel(.hoverOpen), .animate(.compactIn)])
        #expect(m.surface == .compact)
    }

    @Test("Музыка исчезла без живого календаря: флаг уборки снимается, дальше нечего прятать")
    func mediaClearedResetsDismissedWithoutCalendar() {
        var m = Self.compact()
        _ = IslandMachine.reduce(&m, .activityDismissed)
        #expect(m.dismissed)
        _ = IslandMachine.reduce(&m, .mediaCleared)
        #expect(!m.dismissed)
    }

    @Test("Музыка исчезла, но календарь ещё жив: флаг уборки остаётся — прятать всё ещё есть что")
    func mediaClearedKeepsDismissedWithLiveCalendar() {
        var m = Self.compact()
        m.calendarLive = true
        m.surface = .calendar
        _ = IslandMachine.reduce(&m, .activityDismissed)
        #expect(m.dismissed)
        _ = IslandMachine.reduce(&m, .mediaCleared)
        #expect(m.dismissed)
    }

    @Test("Календарь закрылся без музыки на экране: флаг уборки снимается")
    func calendarEndedResetsDismissedWithoutMedia() {
        var m = IslandModel(config: .alcove)
        m.calendarLive = true
        m.surface = .calendar
        _ = IslandMachine.reduce(&m, .activityDismissed)
        #expect(m.dismissed)
        _ = IslandMachine.reduce(&m, .calendarLiveChanged(false))
        #expect(!m.dismissed)
    }

    @Test("Календарь закрылся, но музыка играет: флаг уборки остаётся")
    func calendarEndedKeepsDismissedWithMedia() {
        var m = Self.compact()
        m.calendarLive = true
        m.surface = .calendar
        _ = IslandMachine.reduce(&m, .activityDismissed)
        #expect(m.dismissed)
        _ = IslandMachine.reduce(&m, .calendarLiveChanged(false))
        #expect(m.dismissed)
    }

    /// Свайп-дисмисс во время окна календаря с музыкой уводит остров в вырез. Новый трек снимает dismissed
    /// (review финала P2, п.1): раньше ветка .idle шла прямиком в .compact, теряя бейдж календаря на весь
    /// остаток окна, хотя base уже вернулся в .calendar
    static func dismissedDuringCalendarWithMusic() -> IslandModel {
        var m = Self.compact()
        m.calendarLive = true
        m.surface = .calendar
        _ = IslandMachine.reduce(&m, .activityDismissed)
        return m
    }

    @Test("Новый трек после дисмисса на окне календаря возвращает calendar, а не голый компакт музыки")
    func trackChangedAfterDismissDuringCalendarRestoresCalendar() {
        var m = Self.dismissedDuringCalendarWithMusic()
        #expect(m.surface == .idle && m.dismissed)
        #expect(IslandMachine.reduce(&m, .trackChanged) == [.animate(.compactIn)])
        #expect(m.surface == .calendar)
        #expect(!m.dismissed)
    }

    @Test("То же самое при выключенном Now Playing: showsMedia == false не должен держать остров в вырезе")
    func trackChangedAfterDismissDuringCalendarWithNowPlayingOffRestoresCalendar() {
        var m = Self.dismissedDuringCalendarWithMusic()
        m.config.nowPlaying.isEnabled = false
        #expect(m.surface == .idle && m.dismissed && !m.showsMedia)
        #expect(IslandMachine.reduce(&m, .trackChanged) == [.animate(.compactIn)])
        #expect(m.surface == .calendar)
        #expect(!m.dismissed)
    }

    @Test("Тот же сценарий через pausedTrackChanged (новый трек пришёл уже на паузе)")
    func pausedTrackChangedAfterDismissDuringCalendarRestoresCalendar() {
        // hasMedia && !mediaIdle: pausedTrackChanged форвардит в trackChanged + playbackChanged(false)
        // (иначе, без активной музыки на экране, это была бы просто пометка «трек пришёл на паузе»)
        var m = Self.dismissedDuringCalendarWithMusic()
        #expect(m.surface == .idle && m.dismissed)
        let effects = IslandMachine.reduce(&m, .pausedTrackChanged)
        #expect(effects.contains(.animate(.compactIn)))
        #expect(m.surface == .calendar)
        #expect(!m.dismissed)
    }
}
