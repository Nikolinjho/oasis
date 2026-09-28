import Testing
@testable import IslandCore

struct IslandMachineExpandedViewTests {
    static func model(_ surface: Surface, view: ExpandedView = .duo, config: IslandMachine.Config = .alcove) -> IslandModel {
        var model = IslandModel(config: config)
        model.surface = surface
        model.expandedView = view
        return model
    }

    @Test("Цикл видов: Duo → плеер → календарь → Duo, меняется только контент")
    func cycle() {
        var m = Self.model(.expanded)
        var seen: [ExpandedView] = []
        for _ in 0..<3 {
            #expect(IslandMachine.reduce(&m, .expandedViewCycled) == [.animate(.viewSwap)])
            seen.append(m.expandedView)
        }
        #expect(seen == [.player, .calendar, .duo])
        #expect(m.surface == .expanded)
    }

    @Test("Вне раскрытого листать нечего")
    func onlyWhenExpanded() {
        var m = Self.model(.compact)
        #expect(IslandMachine.reduce(&m, .expandedViewCycled).isEmpty)
        #expect(m.expandedView == .duo)
    }

    @Test("Во время отклика на hover и сжатия листать нечего")
    func notDuringNudgeOrShrink() {
        var nudge = Self.model(.hoverNudge(from: .compact), view: .player, config: .user)
        #expect(IslandMachine.reduce(&nudge, .expandedViewCycled).isEmpty)
        #expect(nudge.expandedView == .player)

        var shrink = Self.model(.shrink, view: .calendar)
        shrink.pending = .compact
        #expect(IslandMachine.reduce(&shrink, .expandedViewCycled).isEmpty)
        #expect(shrink.expandedView == .calendar)
        #expect(shrink.surface == .shrink)
    }

    @Test("Каждое раскрытие начинается с Duo: клик, hover пользователя, отклик по таймеру")
    func reopenResetsToDuo() {
        var click = Self.model(.compact, view: .calendar)
        _ = IslandMachine.reduce(&click, .clicked)
        #expect(click.expandedView == .duo)

        var hover = Self.model(.compact, view: .player, config: .user)
        _ = IslandMachine.reduce(&hover, .hoverEntered)
        #expect(hover.surface == .expanded)
        #expect(hover.expandedView == .duo)

        var timer = Self.model(.hoverNudge(from: .idle), view: .calendar, config: .user)
        _ = IslandMachine.reduce(&timer, .timerFired(.hoverOpen))
        #expect(timer.surface == .expanded)
        #expect(timer.expandedView == .duo)

        var nudgeClick = Self.model(.hoverNudge(from: .compact), view: .player, config: .user)
        _ = IslandMachine.reduce(&nudgeClick, .clicked)
        #expect(nudgeClick.surface == .expanded)
        #expect(nudgeClick.expandedView == .duo)

        var hoverClick = Self.model(.hover, view: .calendar, config: .alcove)
        _ = IslandMachine.reduce(&hoverClick, .clicked)
        #expect(hoverClick.surface == .expanded)
        #expect(hoverClick.expandedView == .duo)
    }

    @Test("После HUD из раскрытого на плеере новое раскрытие начинается с Duo")
    func reopenAfterHUD() {
        var m = Self.model(.expanded, view: .player, config: .user)
        m.hasMedia = true
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(m.surface == .hud(.volume, level: 0.5))
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .compact)
        _ = IslandMachine.reduce(&m, .clicked)
        #expect(m.surface == .expanded)
        #expect(m.expandedView == .duo)
    }
}
