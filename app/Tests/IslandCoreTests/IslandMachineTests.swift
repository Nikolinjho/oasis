import Testing
@testable import IslandCore

/// Режим Alcove: компакт в покое, hover даёт мини-состояние. На нём записан эталон сверки
struct IslandMachineTests {
    static let hideHUD = IslandEffect.schedule(.hudHide, after: IslandTiming.hudVisible)
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)
    static let shrinkEffects: [IslandEffect] = [.cancel(.peekEnd), .animate(.shrink), startGrow]

    static func model(_ surface: Surface, media: Bool = false, pending: Surface? = nil) -> IslandModel {
        var model = IslandModel(config: .alcove)
        model.surface = surface
        model.hasMedia = media
        model.pending = pending
        return model
    }

    // MARK: - Музыка

    @Test("Первый трек из покоя открывает компакт")
    func firstTrack() {
        var m = IslandModel(config: .alcove)
        let fx = IslandMachine.reduce(&m, .trackChanged)
        #expect(m.surface == .compact)
        #expect(m.hasMedia)
        #expect(fx == [.animate(.compactIn)])
    }

    @Test("Смена трека в компакте показывает peek на 2 с")
    func nextTrackPeeks() {
        var m = Self.model(.compact, media: true)
        let fx = IslandMachine.reduce(&m, .trackChanged)
        #expect(m.surface == .peek)
        #expect(fx == [.animate(.peekOpen), .schedule(.peekEnd, after: .seconds(2))])
    }

    @Test("Повторная смена трека во время peek таймер не перезапускает")
    func peekIsNotRestarted() {
        var m = Self.model(.peek, media: true)
        let fx = IslandMachine.reduce(&m, .trackChanged)
        #expect(m.surface == .peek)
        #expect(fx.isEmpty)
    }

    @Test("Peek по таймеру возвращается в компакт")
    func peekEnds() {
        var m = Self.model(.peek, media: true)
        let fx = IslandMachine.reduce(&m, .timerFired(.peekEnd))
        #expect(m.surface == .compact)
        #expect(fx == [.animate(.peekClose)])
    }

    @Test("Устаревший таймер peek ничего не делает")
    func stalePeekTimer() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .timerFired(.peekEnd)).isEmpty)
        #expect(m.surface == .compact)
    }

    @Test("Музыка пропала: компакт уходит в покой")
    func mediaCleared() {
        var m = Self.model(.compact, media: true)
        let fx = IslandMachine.reduce(&m, .mediaCleared)
        #expect(m.surface == .idle)
        #expect(!m.hasMedia)
        #expect(fx == [.cancel(.peekEnd), .animate(.compactOut)])
    }

    @Test("Трек во время HUD только отмечает музыку, компакт появится после HUD")
    func trackDuringHUD() {
        var m = Self.model(.hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .trackChanged).isEmpty)
        #expect(m.hasMedia)
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .timerFired(.hudHide)) == Self.shrinkEffects)
        #expect(m.pending == .compact)
    }

    // MARK: - HUD

    @Test("HUD из покоя появляется сразу")
    func hudFromIdle() {
        var m = IslandModel(config: .alcove)
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(fx == [.animate(.hudIn), Self.hideHUD])
    }

    @Test("Новый уровень продлевает HUD и не анимирует форму")
    func hudUpdate() {
        var m = Self.model(.hud(.volume, level: 0.5))
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5625))
        #expect(m.surface == .hud(.volume, level: 0.5625))
        #expect(fx == [.animate(.hudUpdate), Self.hideHUD])
    }

    @Test("Без музыки HUD уходит в покой")
    func hudHidesToIdle() {
        var m = Self.model(.hud(.brightness, level: 0.3))
        let fx = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.surface == .idle)
        #expect(fx == [.animate(.hudOut)])
    }

    @Test("HUD поверх компакта: сначала сжатие, потом раскрытие")
    func hudOverCompact() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)) == Self.shrinkEffects)
        #expect(m.surface == .shrink)
        #expect(m.pending == .hud(.volume, level: 0.5))

        let fx = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(m.pending == nil)
        #expect(fx == [.animate(.grow), Self.hideHUD])
    }

    @Test("С музыкой HUD уходит через сжатие обратно в компакт")
    func hudReturnsToCompact() {
        var m = Self.model(.hud(.volume, level: 0.5), media: true)
        #expect(IslandMachine.reduce(&m, .timerFired(.hudHide)) == Self.shrinkEffects)
        #expect(m.surface == .shrink)
        #expect(m.pending == .compact)

        #expect(IslandMachine.reduce(&m, .timerFired(.grow)) == [.animate(.grow)])
        #expect(m.surface == .compact)
    }

    @Test("Во время сжатия новый уровень только запоминается")
    func hudDuringShrink() {
        var m = Self.model(.shrink, media: true, pending: .compact)
        #expect(IslandMachine.reduce(&m, .hudChanged(.brightness, level: 0.3)).isEmpty)
        #expect(m.pending == .hud(.brightness, level: 0.3))
        #expect(m.surface == .shrink)
    }

    @Test("Музыка пропала во время сжатия: раскрываемся в покой")
    func mediaClearedDuringShrink() {
        var m = Self.model(.shrink, media: true, pending: .compact)
        #expect(IslandMachine.reduce(&m, .mediaCleared).isEmpty)
        #expect(m.pending == .idle)
        #expect(IslandMachine.reduce(&m, .timerFired(.grow)) == [.animate(.grow)])
        #expect(m.surface == .idle)
    }

    @Test("Устаревший таймер grow ничего не делает")
    func staleGrowTimer() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .timerFired(.grow)).isEmpty)
        #expect(m.surface == .compact)
    }

    // MARK: - HUD при раскрытом острове

    @Test("HUD при раскрытом плеере: схлопывание, затем HUD как из компакта")
    func hudOverExpandedWithMedia() {
        var m = Self.model(.expanded, media: true)
        let collapse = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.4))
        #expect(collapse == [.animate(.collapse), .schedule(.collapseDone, after: IslandTiming.collapse)])
        #expect(m.surface == .compact)
        #expect(m.pending == .hud(.volume, level: 0.4))

        #expect(IslandMachine.reduce(&m, .timerFired(.collapseDone)) == Self.shrinkEffects)
        #expect(m.surface == .shrink)
        #expect(m.pending == .hud(.volume, level: 0.4))

        #expect(IslandMachine.reduce(&m, .timerFired(.grow)) == [.animate(.grow), Self.hideHUD])
        #expect(m.surface == .hud(.volume, level: 0.4))
    }

    @Test("HUD при раскрытом без музыки: после схлопывания сразу HUD")
    func hudOverExpandedWithoutMedia() {
        var m = Self.model(.expanded)
        _ = IslandMachine.reduce(&m, .hudChanged(.brightness, level: 0.7))
        #expect(m.surface == .idle)
        #expect(IslandMachine.reduce(&m, .timerFired(.collapseDone)) == [.animate(.hudIn), Self.hideHUD])
        #expect(m.surface == .hud(.brightness, level: 0.7))
        #expect(m.pending == nil)
    }

    @Test("Уровень, пришедший во время схлопывания, берётся последним")
    func latestLevelWins() {
        var m = Self.model(.expanded, media: true)
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.4))
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)).isEmpty)
        _ = IslandMachine.reduce(&m, .timerFired(.collapseDone))
        #expect(m.pending == .hud(.volume, level: 0.5))
    }

    @Test("HUD из hover тоже сначала схлопывает")
    func hudOverHover() {
        var m = Self.model(.hover)
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.4))
        #expect(fx == [.animate(.collapse), .schedule(.collapseDone, after: IslandTiming.collapse)])
        #expect(m.surface == .idle)
    }

    // MARK: - Hover и клик

    @Test("Hover из покоя и обратно")
    func hoverInAndOut() {
        var m = IslandModel(config: .alcove)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverOpen)])
        #expect(m.surface == .hover)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.animate(.collapse)])
        #expect(m.surface == .idle)
    }

    @Test("Клик по компакту раскрывает плеер, клик мимо схлопывает в компакт")
    func clickAndClickOutside() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .clicked) == [.cancel(.peekEnd), .animate(.expand)])
        #expect(m.surface == .expanded)
        #expect(IslandMachine.reduce(&m, .clickedOutside) == [.animate(.collapse)])
        #expect(m.surface == .compact)
    }

    @Test("Клик из hover раскрывает плеер")
    func clickFromHover() {
        var m = Self.model(.hover, media: true)
        #expect(IslandMachine.reduce(&m, .clicked) == [.cancel(.peekEnd), .animate(.expand)])
        #expect(m.surface == .expanded)
    }

    @Test("Увод курсора из раскрытого схлопывает")
    func hoverExitFromExpanded() {
        var m = Self.model(.expanded, media: true)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.animate(.collapse)])
        #expect(m.surface == .compact)
    }

    @Test("Повторный hover в hover и клик в раскрытом ничего не делают")
    func repeatedOpen() {
        var hover = Self.model(.hover)
        #expect(IslandMachine.reduce(&hover, .hoverEntered).isEmpty)
        var expanded = Self.model(.expanded)
        #expect(IslandMachine.reduce(&expanded, .clicked).isEmpty)
    }

    @Test("HUD не реагирует на hover и клик")
    func hudIgnoresPointer() {
        var m = Self.model(.hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .hoverEntered).isEmpty)
        #expect(IslandMachine.reduce(&m, .clicked).isEmpty)
        #expect(m.surface == .hud(.volume, level: 0.5))
    }

    @Test("Hover во время схлопывания перед HUD игнорируется")
    func hoverWhilePending() {
        var m = Self.model(.idle, pending: .hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .hoverEntered).isEmpty)
        #expect(m.surface == .idle)
    }

    // MARK: - Покрытие спеки: клик в покое, hover из музыки, потеря музыки

    @Test("Клик в покое без музыки раскрывает пустой плеер")
    func clickFromIdle() {
        var m = IslandModel(config: .alcove)
        #expect(IslandMachine.reduce(&m, .clicked) == [.cancel(.peekEnd), .animate(.expand)])
        #expect(m.surface == .expanded)
        #expect(!m.hasMedia)
    }

    @Test("Hover из компакта открывает hover")
    func hoverFromCompact() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverOpen)])
        #expect(m.surface == .hover)
    }

    @Test("Hover из peek отменяет таймер peek и открывает hover")
    func hoverFromPeek() {
        var m = Self.model(.peek, media: true)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverOpen)])
        #expect(m.surface == .hover)
    }

    @Test("Музыка пропала во время peek: уходим в покой, таймер peek отменён")
    func mediaClearedDuringPeek() {
        var m = Self.model(.peek, media: true)
        #expect(IslandMachine.reduce(&m, .mediaCleared) == [.cancel(.peekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
        #expect(!m.hasMedia)
    }

    @Test("Музыка пропала во время HUD: после HUD остров уходит в покой без сжатия")
    func mediaClearedDuringHUD() {
        var m = Self.model(.hud(.volume, level: 0.5), media: true)
        #expect(IslandMachine.reduce(&m, .mediaCleared).isEmpty)
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(!m.hasMedia)
        #expect(IslandMachine.reduce(&m, .timerFired(.hudHide)) == [.animate(.hudOut)])
        #expect(m.surface == .idle)
        #expect(m.pending == nil)
    }
}
