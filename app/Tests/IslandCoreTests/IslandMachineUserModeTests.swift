import Testing
@testable import IslandCore

/// Hover сразу раскрывает плеер (режим пользователя) и покой в форме выреза (compactAtRest = false)
struct IslandMachineUserModeTests {
    /// Покой в форме выреза: компакт только на время peek
    static let notchRest = IslandMachine.Config(hoverOpensPlayer: true, compactAtRest: false)

    static let hideHUD = IslandEffect.schedule(.hudHide, after: IslandTiming.hudVisible)
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)
    static let shrinkEffects: [IslandEffect] = [.cancel(.peekEnd), .animate(.shrink), startGrow]
    static let peekEffects: [IslandEffect] = [.animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek)]
    static let nudgeEffects: [IslandEffect] = [
        .cancel(.peekEnd), .animate(.hoverNudge), .schedule(.hoverOpen, after: IslandTiming.hoverNudge),
    ]

    static func model(_ surface: Surface, media: Bool = false, pending: Surface? = nil) -> IslandModel {
        var model = IslandModel(config: notchRest)
        model.surface = surface
        model.hasMedia = media
        model.pending = pending
        return model
    }

    // MARK: - Настройка

    @Test("По умолчанию пользовательский режим: hover раскрывает плеер, компакт в покое как у Alcove")
    func configs() {
        #expect(IslandModel().config == .user)
        #expect(IslandMachine.Config.user.hoverOpensPlayer)
        #expect(IslandMachine.Config.user.compactAtRest)
        #expect(!IslandMachine.Config.alcove.hoverOpensPlayer)
        #expect(IslandMachine.Config.alcove.compactAtRest)
    }

    // MARK: - Режим пользователя по умолчанию

    @Test("Режим пользователя: первый трек открывает компакт, peek возвращается в компакт")
    func userModeKeepsCompact() {
        var m = IslandModel()
        #expect(IslandMachine.reduce(&m, .trackChanged) == [.animate(.compactIn)])
        #expect(m.surface == .compact)
        #expect(IslandMachine.reduce(&m, .trackChanged) == Self.peekEffects)
        #expect(IslandMachine.reduce(&m, .timerFired(.peekEnd)) == [.animate(.peekClose)])
        #expect(m.surface == .compact)
    }

    @Test("Режим пользователя: hover из компакта раскрывает плеер, уход курсора возвращает компакт")
    func userModeHoverFromCompact() {
        var m = IslandModel()
        m.surface = .compact
        m.hasMedia = true
        _ = IslandMachine.reduce(&m, .hoverEntered)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
        #expect(IslandMachine.reduce(&m, .clicked).isEmpty)
        _ = IslandMachine.reduce(&m, .hoverExited)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverLeave)) == [.animate(.collapse)])
        #expect(m.surface == .compact)
    }

    @Test("Режим пользователя: hover из покоя без музыки раскрывает пустой плеер")
    func userModeHoverFromIdle() {
        var m = IslandModel()
        _ = IslandMachine.reduce(&m, .hoverEntered)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
        #expect(!m.hasMedia)
    }

    // MARK: - Покой в форме выреза

    @Test("Покой с музыкой — форма выреза")
    func baseIsIdle() {
        #expect(Self.model(.idle, media: true).base == .idle)
    }

    @Test("Первый трек из покоя показывает peek, а не постоянный компакт")
    func firstTrackPeeks() {
        var m = IslandModel(config: Self.notchRest)
        #expect(IslandMachine.reduce(&m, .trackChanged) == Self.peekEffects)
        #expect(m.surface == .peek)
        #expect(m.hasMedia)
    }

    @Test("Следующий трек при музыке в покое снова показывает peek")
    func nextTrackPeeks() {
        var m = Self.model(.idle, media: true)
        #expect(IslandMachine.reduce(&m, .trackChanged) == Self.peekEffects)
        #expect(m.surface == .peek)
    }

    @Test("Peek по таймеру сжимается в форму выреза, музыка остаётся")
    func peekEndsToIdle() {
        var m = Self.model(.peek, media: true)
        #expect(IslandMachine.reduce(&m, .timerFired(.peekEnd)) == [.animate(.compactOut)])
        #expect(m.surface == .idle)
        #expect(m.hasMedia)
    }

    @Test("Музыка пропала во время peek: уход в покой, таймер отменён")
    func mediaClearedDuringPeek() {
        var m = Self.model(.peek, media: true)
        #expect(IslandMachine.reduce(&m, .mediaCleared) == [.cancel(.peekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
        #expect(!m.hasMedia)
    }

    @Test("Трек во время сжатия к HUD не меняет цель после HUD: покой остаётся покоем")
    func trackDuringShrinkKeepsIdle() {
        var m = Self.model(.shrink, pending: .idle)
        #expect(IslandMachine.reduce(&m, .trackChanged).isEmpty)
        #expect(m.pending == .idle)
        #expect(m.hasMedia)
    }

    @Test("Hover из покоя через отклик раскрывает полный плеер")
    func hoverOpensPlayer() {
        var m = IslandModel(config: Self.notchRest)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == Self.nudgeEffects)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
    }

    @Test("Hover из покоя с музыкой открывает плеер с треком")
    func hoverWithMediaOpensPlayer() {
        var m = Self.model(.idle, media: true)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == Self.nudgeEffects)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
        #expect(m.hasMedia)
    }

    @Test("Клик из покоя с музыкой открывает плеер с треком")
    func clickWithMediaOpensPlayer() {
        var m = Self.model(.idle, media: true)
        #expect(IslandMachine.reduce(&m, .clicked) == [.cancel(.peekEnd), .animate(.expand)])
        #expect(m.surface == .expanded)
        #expect(m.hasMedia)
    }

    @Test("Hover во время peek отменяет таймер и раскрывает плеер через отклик")
    func hoverFromPeek() {
        var m = Self.model(.peek, media: true)
        #expect(IslandMachine.reduce(&m, .hoverEntered) == Self.nudgeEffects)
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverOpen)) == [.animate(.hoverExpand)])
        #expect(m.surface == .expanded)
    }

    @Test("Клик внутри раскрытого по hover плеера его не закрывает")
    func clickInsideKeepsPlayer() {
        var m = Self.model(.expanded, media: true)
        #expect(IslandMachine.reduce(&m, .clicked).isEmpty)
        #expect(m.surface == .expanded)
    }

    @Test("Уход курсора после задержки схлопывает плеер в форму выреза")
    func hoverExitCollapsesToIdle() {
        var m = Self.model(.expanded, media: true)
        #expect(IslandMachine.reduce(&m, .hoverExited) == [.schedule(.hoverLeave, after: IslandTiming.hoverLeave)])
        #expect(IslandMachine.reduce(&m, .timerFired(.hoverLeave)) == [.animate(.collapse)])
        #expect(m.surface == .idle)
        #expect(m.hasMedia)
    }

    @Test("Клик мимо схлопывает плеер в форму выреза")
    func clickOutsideCollapsesToIdle() {
        var m = Self.model(.expanded, media: true)
        #expect(IslandMachine.reduce(&m, .clickedOutside) == [.animate(.collapse)])
        #expect(m.surface == .idle)
    }

    @Test("Hover-переходы открывают остров по наведению, клик и схлопывание — нет")
    func hoverTransitions() {
        #expect(IslandTransition.hoverExpand.opensByHover)
        #expect(IslandTransition.hoverOpen.opensByHover)
        #expect(!IslandTransition.expand.opensByHover)
        #expect(!IslandTransition.collapse.opensByHover)
    }

    @Test("HUD при музыке в покое появляется сразу и возвращает в форму выреза")
    func hudAtRestWithMedia() {
        var m = Self.model(.idle, media: true)
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)) == [.animate(.hudIn), Self.hideHUD])
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .timerFired(.hudHide)) == [.animate(.hudOut)])
        #expect(m.surface == .idle)
        #expect(m.hasMedia)
    }

    @Test("HUD во время peek: сжатие, раскрытие в HUD, потом форма выреза")
    func hudDuringPeek() {
        var m = Self.model(.peek, media: true)
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)) == Self.shrinkEffects)
        #expect(IslandMachine.reduce(&m, .timerFired(.grow)) == [.animate(.grow), Self.hideHUD])
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .timerFired(.hudHide)) == [.animate(.hudOut)])
        #expect(m.surface == .idle)
    }

    @Test("HUD при раскрытом плеере с музыкой: схлопывание в покой, затем HUD без сжатия")
    func hudOverExpandedWithMedia() {
        var m = Self.model(.expanded, media: true)
        let collapse = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.4))
        #expect(collapse == [.animate(.collapse), .schedule(.collapseDone, after: IslandTiming.collapse)])
        #expect(m.surface == .idle)
        #expect(IslandMachine.reduce(&m, .timerFired(.collapseDone)) == [.animate(.hudIn), Self.hideHUD])
        #expect(m.surface == .hud(.volume, level: 0.4))
    }
}
