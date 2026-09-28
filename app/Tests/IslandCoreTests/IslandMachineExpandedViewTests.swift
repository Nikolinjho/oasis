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
        #expect(timer.expandedView == .duo)
    }
}
