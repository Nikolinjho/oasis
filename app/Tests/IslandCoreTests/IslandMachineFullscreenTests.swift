import Testing
@testable import IslandCore

/// Полноэкранное приложение на экране с вырезом: компакт и peek музыки прячутся, плеер и HUD работают
struct IslandMachineFullscreenTests {
    static let configs: [IslandMachine.Config] = [.user, .alcove]
    static let hideHUD = IslandEffect.schedule(.hudHide, after: IslandTiming.hudVisible)

    static func model(_ config: IslandMachine.Config, _ surface: Surface, media: Bool = true, fullscreen: Bool = true) -> IslandModel {
        var model = IslandModel(config: config)
        model.surface = surface
        model.hasMedia = media
        model.isFullscreen = fullscreen
        return model
    }

    @Test("В полноэкранном покой — форма выреза даже с музыкой", arguments: configs)
    func baseIsIdle(config: IslandMachine.Config) {
        #expect(Self.model(config, .idle).base == .idle)
        #expect(Self.model(config, .idle, fullscreen: false).base == .compact)
    }

    @Test("Вход в полноэкранный прячет компакт", arguments: configs)
    func enterHidesCompact(config: IslandMachine.Config) {
        var m = Self.model(config, .compact, fullscreen: false)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)) == [.cancel(.peekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
        #expect(m.isFullscreen)
        #expect(m.hasMedia)
    }

    @Test("Вход в полноэкранный во время peek прячет его и отменяет таймер", arguments: configs)
    func enterHidesPeek(config: IslandMachine.Config) {
        var m = Self.model(config, .peek, fullscreen: false)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)) == [.cancel(.peekEnd), .animate(.compactOut)])
        #expect(m.surface == .idle)
    }

    @Test("Смена трека в полноэкранном только запоминает музыку", arguments: configs)
    func trackIsRecorded(config: IslandMachine.Config) {
        var m = Self.model(config, .idle, media: false)
        #expect(IslandMachine.reduce(&m, .trackChanged).isEmpty)
        #expect(m.hasMedia)
        #expect(m.surface == .idle)
        #expect(IslandMachine.reduce(&m, .trackChanged).isEmpty)
        #expect(m.surface == .idle)
    }

    @Test("Выход из полноэкранного с музыкой возвращает компакт", arguments: configs)
    func leaveShowsCompact(config: IslandMachine.Config) {
        var m = Self.model(config, .idle)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(false)) == [.animate(.compactIn)])
        #expect(m.surface == .compact)
        #expect(!m.isFullscreen)
    }

    @Test("Выход из полноэкранного без музыки ничего не анимирует", arguments: configs)
    func leaveWithoutMedia(config: IslandMachine.Config) {
        var m = Self.model(config, .idle, media: false)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(false)).isEmpty)
        #expect(m.surface == .idle)
    }

    @Test("Повтор того же состояния полноэкранного ничего не делает", arguments: configs)
    func repeatedIsNoop(config: IslandMachine.Config) {
        var m = Self.model(config, .idle)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)).isEmpty)
        var off = Self.model(config, .compact, fullscreen: false)
        #expect(IslandMachine.reduce(&off, .fullscreenChanged(false)).isEmpty)
        #expect(off.surface == .compact)
    }

    @Test("В полноэкранном hover и клик по-прежнему открывают остров")
    func pointerStillOpens() {
        var user = Self.model(.user, .idle)
        #expect(IslandMachine.reduce(&user, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverExpand)])
        #expect(user.surface == .expanded)
        var alcove = Self.model(.alcove, .idle)
        #expect(IslandMachine.reduce(&alcove, .hoverEntered) == [.cancel(.peekEnd), .animate(.hoverOpen)])
        #expect(alcove.surface == .hover)
        var click = Self.model(.alcove, .idle)
        #expect(IslandMachine.reduce(&click, .clicked) == [.cancel(.peekEnd), .animate(.expand)])
        #expect(click.surface == .expanded)
    }

    @Test("Вход в полноэкранный не закрывает открытый плеер, уход курсора схлопывает в вырез", arguments: configs)
    func openPlayerStays(config: IslandMachine.Config) {
        var m = Self.model(config, .expanded, fullscreen: false)
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)).isEmpty)
        #expect(m.surface == .expanded)
        // в режиме пользователя схлопывание идёт после задержки ухода
        let exit = IslandMachine.reduce(&m, .hoverExited)
        let collapse = config.hoverOpensPlayer ? IslandMachine.reduce(&m, .timerFired(.hoverLeave)) : exit
        #expect(collapse == [.animate(.collapse)])
        #expect(m.surface == .idle)
    }

    @Test("HUD в полноэкранном работает и возвращает в форму выреза", arguments: configs)
    func hudInFullscreen(config: IslandMachine.Config) {
        var m = Self.model(config, .idle)
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)) == [.animate(.hudIn), Self.hideHUD])
        #expect(m.surface == .hud(.volume, level: 0.5))
        #expect(IslandMachine.reduce(&m, .timerFired(.hudHide)) == [.animate(.hudOut)])
        #expect(m.surface == .idle)
    }

    @Test("Вход в полноэкранный во время сжатия к компакту: раскрытие пойдёт в вырез", arguments: configs)
    func enterDuringShrink(config: IslandMachine.Config) {
        var m = Self.model(config, .shrink, fullscreen: false)
        m.pending = .compact
        #expect(IslandMachine.reduce(&m, .fullscreenChanged(true)).isEmpty)
        #expect(m.pending == .idle)
    }
}
