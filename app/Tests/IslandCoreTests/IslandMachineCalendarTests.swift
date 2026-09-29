import Testing
@testable import IslandCore

/// Компакт календаря — второй вид покоя (решение 27.09): вытесняет музыку на время события
struct IslandMachineCalendarTests {
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)
    static let shrinkEffects: [IslandEffect] = [.cancel(.peekEnd), .animate(.shrink), startGrow]
    /// Сжатие из широкого HUD — своя пружина без отскока (shrinkTransition в master после P0)
    static let shrinkFromWideEffects: [IslandEffect] = [.cancel(.peekEnd), .animate(.shrinkFromWide), startGrow]

    static func model(_ surface: Surface, media: Bool = false, live: Bool = false, config: IslandMachine.Config = .alcove) -> IslandModel {
        var model = IslandModel(config: config)
        model.surface = surface
        model.hasMedia = media
        model.calendarLive = live
        return model
    }

    @Test("Окно календаря из покоя открывает компакт календаря")
    func liveFromIdle() {
        var m = Self.model(.idle)
        let fx = IslandMachine.reduce(&m, .calendarLiveChanged(true))
        #expect(m.surface == .calendar)
        #expect(fx == [.animate(.compactIn)])
    }

    @Test("Окно календаря при музыке: компакт музыки сжимается и раскрывается в календарь")
    func liveReplacesMusic() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .calendarLiveChanged(true)) == Self.shrinkEffects)
        #expect(m.pending == .calendar)
    }

    @Test("Конец окна при музыке — снова музыка через сжатие, без музыки — покой")
    func liveEnds() {
        var music = Self.model(.calendar, media: true, live: true)
        #expect(IslandMachine.reduce(&music, .calendarLiveChanged(false)) == Self.shrinkEffects)
        #expect(music.pending == .compact)

        var silent = Self.model(.calendar, live: true)
        #expect(IslandMachine.reduce(&silent, .calendarLiveChanged(false)) == [.animate(.compactOut)])
        #expect(silent.surface == .idle)
    }

    @Test("Старт события: peek на 4.2 с и звук, из раскрытого — только звук")
    func started() {
        var m = Self.model(.calendar, live: true)
        let fx = IslandMachine.reduce(&m, .calendarStarted)
        #expect(m.surface == .calendarPeek)
        #expect(fx == [.animate(.calendarPeekOpen), .schedule(.calendarPeekEnd, after: IslandTiming.calendarPeek), .play(.event)])

        var open = Self.model(.expanded, live: true)
        #expect(IslandMachine.reduce(&open, .calendarStarted) == [.play(.event)])
        #expect(open.surface == .expanded)
    }

    @Test("Peek календаря по таймеру возвращается в компакт календаря")
    func peekEnds() {
        var m = Self.model(.calendarPeek, live: true)
        #expect(IslandMachine.reduce(&m, .timerFired(.calendarPeekEnd)) == [.animate(.calendarPeekClose)])
        #expect(m.surface == .calendar)
    }

    @Test("Окно закрылось во время peek: таймер снимается, остров уходит в новый покой")
    func liveEndsDuringPeek() {
        var m = Self.model(.calendarPeek, live: true)
        let fx = IslandMachine.reduce(&m, .calendarLiveChanged(false))
        #expect(fx == [.cancel(.calendarPeekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
    }

    @Test("Трек во время окна календаря: компакт остаётся календарём, но перестраивается под музыку на месте")
    func trackDuringLive() {
        var m = Self.model(.calendar, live: true)
        #expect(IslandMachine.reduce(&m, .trackChanged) == [.animate(.calendarRestyle)])
        #expect(m.hasMedia)
        #expect(m.surface == .calendar)
    }

    @Test("HUD, уведомление и раскрытый возвращаются в компакт календаря, сжатие — пружиной источника")
    func returnsToCalendar() {
        var hud = Self.model(.hud(.volume, level: 0.5), media: true, live: true)
        #expect(IslandMachine.reduce(&hud, .timerFired(.hudHide)) == Self.shrinkFromWideEffects)
        #expect(hud.pending == .calendar)

        // из уведомления — пружина сжатия уведомления (замер Charging → сжатие)
        var alert = Self.model(.alert(.charging(level: 0.8)), media: true, live: true)
        #expect(IslandMachine.reduce(&alert, .timerFired(.alertHide)) == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(alert.pending == .calendar)

        var open = Self.model(.expanded, media: true)
        _ = IslandMachine.reduce(&open, .calendarLiveChanged(true))
        #expect(open.surface == .expanded)
        #expect(IslandMachine.reduce(&open, .clickedOutside) == [.animate(.collapse)])
        #expect(open.surface == .calendar)
    }

    @Test("Hover по компакту календаря раскрывает остров, как по компакту музыки")
    func hoverOpens() {
        var m = Self.model(.calendar, live: true, config: .user)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverExpand)])
        #expect(m.surface == .expanded)
    }

    @Test("Полноэкранное приложение прячет компакт календаря")
    func fullscreenHides() {
        var m = Self.model(.calendar, live: true)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)) == [.cancel(.calendarPeekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(false)) == [.animate(.compactIn)])
        #expect(m.surface == .calendar)
    }

    @Test("Peek музыки кончился, а окно календаря уже открыто: смена через сжатие")
    func musicPeekEndsIntoCalendar() {
        var m = Self.model(.peek, media: true, live: true)
        #expect(IslandMachine.reduce(&m, .timerFired(.peekEnd)) == Self.shrinkEffects)
        #expect(m.pending == .calendar)
    }

    @Test("Peek музыки на экране, открылось окно календаря: peek прерывается сжатием в календарь")
    func liveInterruptsMusicPeek() {
        var m = Self.model(.compact, media: true)
        _ = IslandMachine.reduce(&m, .trackChanged)
        #expect(m.surface == .peek)
        #expect(IslandMachine.reduce(&m, .calendarLiveChanged(true)) == Self.shrinkEffects)
        #expect(m.surface == .shrink)
        #expect(m.pending == .calendar)
        #expect(IslandMachine.reduce(&m, .timerFired(.grow)) == [.animate(.grow)])
        #expect(m.surface == .calendar)
    }

    @Test("Сжатие HUD к компакту музыки, открылось окно: цель сжатия — компакт календаря")
    func liveRetargetsShrinkToCalendar() {
        var m = Self.model(.hud(.volume, level: 0.5), media: true)
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.pending == .compact)
        #expect(IslandMachine.reduce(&m, .calendarLiveChanged(true)).isEmpty)
        #expect(m.surface == .shrink)
        #expect(m.pending == .calendar)
    }

    @Test("Сжатие к компакту календаря, окно закрылось: цель — музыка, без неё форма выреза")
    func liveEndRetargetsShrink() {
        var music = Self.model(.hud(.volume, level: 0.5), media: true, live: true)
        _ = IslandMachine.reduce(&music, .timerFired(.hudHide))
        #expect(music.pending == .calendar)
        #expect(IslandMachine.reduce(&music, .calendarLiveChanged(false)).isEmpty)
        #expect(music.pending == .compact)

        var silent = Self.model(.hud(.volume, level: 0.5), live: true)
        _ = IslandMachine.reduce(&silent, .timerFired(.hudHide))
        #expect(silent.pending == .calendar)
        #expect(IslandMachine.reduce(&silent, .calendarLiveChanged(false)).isEmpty)
        #expect(silent.pending == .idle)
    }

    @Test("Окно закрылось во время peek календаря при музыке: таймер peek снимается, сжатие в музыку")
    func liveEndsDuringPeekWithMusic() {
        var m = Self.model(.calendarPeek, media: true, live: true)
        let fx = IslandMachine.reduce(&m, .calendarLiveChanged(false))
        #expect(fx == [.cancel(.calendarPeekEnd)] + Self.shrinkEffects)
        #expect(m.surface == .shrink)
        #expect(m.pending == .compact)
    }

    @Test("Полноэкранное приложение во время peek календаря снимает его таймер")
    func fullscreenDuringCalendarPeek() {
        var m = Self.model(.calendarPeek, live: true)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)) == [.cancel(.calendarPeekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
    }

    @Test("Hover, клик и HUD поверх peek календаря снимают таймер peek календаря")
    func leavingCalendarPeekCancelsTimer() {
        var hover = Self.model(.calendarPeek, live: true, config: .user)
        #expect(IslandMachine.reduce(&hover, .hoverEntered) == [
            .cancel(.peekEnd), .cancel(.calendarPeekEnd), .animate(.hoverExpand),
        ])

        var click = Self.model(.calendarPeek, live: true)
        #expect(IslandMachine.reduce(&click, .clicked) == [.cancel(.peekEnd), .cancel(.calendarPeekEnd), .animate(.expand)])

        var hud = Self.model(.calendarPeek, live: true)
        #expect(IslandMachine.reduce(&hud, .hudChanged(.volume, level: 0.5)) == [
            .cancel(.peekEnd), .cancel(.calendarPeekEnd), .animate(.shrink), Self.startGrow,
        ])
        #expect(hud.pending == .hud(.volume, level: 0.5))
    }
}
