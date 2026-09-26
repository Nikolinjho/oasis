import Testing
@testable import IslandCore

/// Ненулевая задержка hover (Hover duration у Alcove): сначала отклик (форма чуть шире), плеер по таймеру.
/// Уход курсора схлопывает плеер с задержкой, возврат в неё отменяет схлопывание
struct IslandMachineHoverNudgeTests {
    static let nudging = IslandMachine.Config(
        hoverOpensPlayer: true, compactAtRest: true, timeScale: 1.18, hoverDelay: IslandTiming.hoverNudge)
    static let scale = nudging.timeScale
    static let startOpen = IslandEffect.schedule(.hoverOpen, after: IslandTiming.hoverNudge * scale)
    static let startLeave = IslandEffect.schedule(.hoverLeave, after: IslandTiming.hoverLeave * scale)
    static let nudgeEffects: [IslandEffect] = [.cancel(.peekEnd), .animate(.hoverNudge), startOpen]

    static func model(_ surface: Surface, media: Bool = true, config: IslandMachine.Config = nudging) -> IslandModel {
        var model = IslandModel(config: config)
        model.surface = surface
        model.hasMedia = media
        return model
    }

    /// Плеер, раскрытый наведением, из которого курсор уже ушёл: ждёт схлопывания
    static func leaving() -> IslandModel {
        var m = model(.expanded)
        _ = IslandMachine.reduce(&m, .hoverExited)
        return m
    }

    // MARK: - Отклик и раскрытие

    @Test("Hover из компакта: отклик, по таймеру раскрытие в плеер пружиной hover")
    func nudgeThenExpand() {
        var m = Self.model(.compact)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == Self.nudgeEffects)
        #expect(m.surface == .hoverNudge(from: .compact))
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
    }

    @Test("Hover из покоя и из peek тоже начинается с отклика", arguments: [Surface.idle, .peek])
    func nudgeFromIdleAndPeek(surface: Surface) {
        var m = Self.model(surface, media: surface != .idle)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == Self.nudgeEffects)
        #expect(m.surface == .hoverNudge(from: surface))
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
    }

    @Test("Тайминги отклика и задержки ухода замедляются timeScale")
    func timingsAreScaled() {
        var m = IslandModel(config: IslandMachine.Config(
            hoverOpensPlayer: true, compactAtRest: true, timeScale: 2, hoverDelay: IslandTiming.hoverNudge))
        #expect(IslandMachine.reduce(&m, .hoverEntered).contains(.schedule(.hoverOpen, after: IslandTiming.hoverNudge * 2)))
        _ = IslandMachine.reduce(&m, .timerFired(.hoverOpen))
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.schedule(.hoverLeave, after: IslandTiming.hoverLeave * 2)])
    }

    @Test("Уход курсора до таймера: возврат в компакт без раскрытия")
    func exitBeforeOpen() {
        var m = Self.model(.compact)
        _ = IslandMachine.reduce(&m, .hoverEntered)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.cancel(.hoverOpen), .animate(.hoverNudgeBack)])
        #expect(m.surface == .compact)
        // таймер отменён, но и опоздавший ничего не раскрывает
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)).isEmpty)
        #expect(m.surface == .compact)
    }

    @Test("Уход с отклика из peek возвращает в компакт, а не в peek")
    func exitNudgeFromPeek() {
        var m = Self.model(.peek)
        _ = IslandMachine.reduce(&m, .hoverEntered)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.cancel(.hoverOpen), .animate(.peekClose)])
        #expect(m.surface == .compact)
    }

    @Test("Повторный hover во время отклика ничего не делает")
    func repeatedEnterDuringNudge() {
        var m = Self.model(.hoverNudge(from: .compact))
        #expect(IslandMachine.reduce(&m, .hoverEntered).isEmpty)
        #expect(m.surface == .hoverNudge(from: .compact))
    }

    @Test("Клик во время отклика раскрывает плеер сразу")
    func clickDuringNudge() {
        var m = Self.model(.hoverNudge(from: .compact))
        #expect(IslandMachine.reduce(&m, .clicked) == [.cancel(.hoverOpen), .animate(.expand)])
        #expect(m.surface == .expanded)
    }

    @Test("Hover-открытие даёт один тактильный отклик: на раскрытие, а не на отклик формы")
    func hapticOnce() {
        #expect(!IslandTransition.hoverNudge.opensByHover)
        #expect(!IslandTransition.hoverNudgeBack.opensByHover)
        #expect(IslandTransition.hoverExpand.opensByHover)
    }

    // MARK: - HUD во время отклика

    @Test("HUD во время отклика из компакта: таймер раскрытия отменён, сжатие и HUD")
    func hudDuringNudge() {
        var m = Self.model(.hoverNudge(from: .compact))
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(fx == [
            .cancel(.hoverOpen), .cancel(.peekEnd), .animate(.shrink),
            .schedule(.grow, after: IslandTiming.shrink * Self.scale),
        ])
        #expect(m.surface == .shrink)
        #expect(m.pending == .hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)).isEmpty)
        #expect(m.surface == .shrink)
    }

    @Test("HUD во время отклика из покоя появляется сразу")
    func hudDuringIdleNudge() {
        var m = Self.model(.hoverNudge(from: .idle), media: false)
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(fx == [.cancel(.hoverOpen), .animate(.hudIn), .schedule(.hudHide, after: IslandTiming.hudVisible)])
        #expect(m.surface == .hud(.volume, level: 0.5))
    }

    // MARK: - Уход из плеера

    @Test("Уход курсора из плеера: схлопывание не сразу, а по таймеру")
    func exitDelaysCollapse() {
        var m = Self.model(.expanded)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [Self.startLeave])
        #expect(m.surface == .expanded)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverLeave)) == [.animate(.collapse)])
        #expect(m.surface == .compact)
    }

    @Test("Повторный уход во время задержки таймер не перезапускает")
    func repeatedExit() {
        var m = Self.leaving()
        #expect(IslandMachine.reduce(&m, .hoverExited).isEmpty)
    }

    @Test("Возврат курсора в задержке отменяет схлопывание")
    func returnDuringDelay() {
        var m = Self.leaving()
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.hoverLeave)])
        #expect(m.surface == .expanded)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverLeave)).isEmpty)
        #expect(m.surface == .expanded)
        // следующий уход снова ставит задержку
        #expect(IslandMachine.reduce(&m, .hoverExited) == [Self.startLeave])
    }

    @Test("Hover в раскрытом без задержки ухода ничего не делает")
    func enterExpandedIdle() {
        var m = Self.model(.expanded)
        #expect(IslandMachine.reduce(&m, .hoverEntered).isEmpty)
    }

    @Test("Клик мимо закрывает сразу: и в плеере, и во время задержки ухода")
    func clickOutsideClosesNow() {
        var open = Self.model(.expanded)
        #expect(IslandMachine.reduce(&open, .clickedOutside) == [.animate(.collapse)])
        #expect(open.surface == .compact)
        var leaving = Self.leaving()
        #expect(IslandMachine.reduce(&leaving, .clickedOutside) == [.cancel(.hoverLeave), .animate(.collapse)])
        #expect(leaving.surface == .compact)
        #expect(IslandMachine.reduce(&leaving, .timerFired(.hoverLeave)).isEmpty)
    }

    @Test("HUD во время задержки ухода: таймер отменён, плеер морфится в HUD")
    func hudDuringDelay() {
        var m = Self.leaving()
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.4))
        #expect(fx == [.cancel(.hoverLeave), .animate(.hudMorph), .schedule(.hudHide, after: IslandTiming.hudVisible)])
        #expect(m.surface == .hud(.volume, level: 0.4))
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverLeave)).isEmpty)
        #expect(m.surface == .hud(.volume, level: 0.4))
    }

    @Test("Режим пользователя по умолчанию без задержки hover, как Alcove с Hover duration 0")
    func userHasNoHoverDelay() {
        #expect(IslandMachine.Config.user.hoverDelay == .zero)
        var m = Self.model(.compact, config: .user)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverExpand)])
        #expect(m.surface == .expanded)
    }

    // MARK: - Режим Alcove без изменений

    @Test("Режим Alcove: hover без отклика сразу в мини-состояние, уход схлопывает сразу")
    func alcoveUnchanged() {
        var m = Self.model(.compact, config: .alcove)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverOpen)])
        #expect(m.surface == .hover)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.animate(.collapse)])
        #expect(m.surface == .compact)
        var expanded = Self.model(.expanded, config: .alcove)
        #expect(IslandMachine.reduce(&expanded, .hoverExited) == [.animate(.collapse)])
        #expect(expanded.surface == .compact)
    }
}
