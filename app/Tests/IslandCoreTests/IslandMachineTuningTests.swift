import Testing
@testable import IslandCore

/// Подложка подгонки выреза (Task 17t): пока ползунок Notch width/height в Tuning зажат.
/// Режим Alcove (compactAtRest, без задержки hover), как в IslandMachineAlertTests
struct IslandMachineTuningTests {
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)

    static func model(_ surface: Surface, media: Bool = false, pending: Surface? = nil) -> IslandModel {
        var model = IslandModel(config: .alcove)
        model.surface = surface
        model.hasMedia = media
        model.pending = pending
        return model
    }

    @Test("Из покоя без музыки подсказка появляется сразу")
    func fromIdle() {
        var m = Self.model(.idle)
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.width(-1)))
        #expect(m.surface == .tuning(.width(-1)))
        #expect(fx == [.animate(.tuningIn)])
    }

    @Test("Из компакта музыки — через сжатие, раскрытие пружиной подложки")
    func fromCompact() {
        var m = Self.model(.compact, media: true)
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.height(0)))
        #expect(fx == [.cancel(.peekEnd), .animate(.shrink), Self.startGrow])
        #expect(m.pending == .tuning(.height(0)))
        let grow = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .tuning(.height(0)))
        #expect(grow == [.animate(.grow)])
    }

    @Test("Раскрытый морфится в подложку без сжатия, как в HUD", arguments: [Surface.expanded, .hover])
    func morphsFromExpanded(from: Surface) {
        var m = Self.model(from, media: true)
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.width(2)))
        #expect(m.surface == .tuning(.width(2)))
        #expect(fx == [.animate(.hudMorph)])
    }

    @Test("Новое значение поверх текущей подложки — обновление на месте")
    func valueUpdate() {
        var m = Self.model(.tuning(.width(-1)))
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.width(-2)))
        #expect(m.surface == .tuning(.width(-2)))
        #expect(fx == [.animate(.tuningUpdate)])
    }

    @Test("То же значение подряд — без анимации")
    func sameValueIsNoop() {
        var m = Self.model(.tuning(.height(1)))
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.height(1)))
        #expect(m.surface == .tuning(.height(1)))
        #expect(fx.isEmpty)
    }

    @Test("Отпустили без музыки: подложка уходит в покой напрямую")
    func releaseToIdle() {
        var m = Self.model(.tuning(.width(-1)))
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(nil))
        #expect(m.surface == .idle)
        #expect(fx == [.animate(.tuningOut)])
    }

    @Test("Отпустили при играющей музыке: сжатие пружиной подложки, раскрытие обратно в компакт")
    func releaseToCompact() {
        var m = Self.model(.tuning(.width(-1)), media: true)
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(nil))
        #expect(fx == [.cancel(.peekEnd), .animate(.shrink), Self.startGrow])
        #expect(m.pending == .compact)
        let grow = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .compact)
        #expect(grow == [.animate(.grow)])
    }

    @Test("Отпустили не в подложке (гонка конца драга) — без эффекта")
    func releaseWithoutTuningIsNoop() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .tuningHintChanged(nil)).isEmpty)
        #expect(m.surface == .compact)
    }

    @Test("Во время отклика на hover: раскрытие отменяется, подложка приходит из исходного состояния")
    func duringHoverNudge() {
        var m = Self.model(.hoverNudge(from: .idle))
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.width(0)))
        #expect(fx == [.cancel(.hoverOpen), .animate(.tuningIn)])
        #expect(m.surface == .tuning(.width(0)))
    }

    @Test("Курсор ушёл из раскрытого и ждёт схлопывания: таймер отменяется, дальше — морф")
    func duringLeaving() {
        var m = Self.model(.hover, media: true)
        m.leaving = true
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.height(-1)))
        #expect(fx == [.cancel(.hoverLeave), .animate(.hudMorph)])
        #expect(m.surface == .tuning(.height(-1)))
    }

    @Test("HUD важнее подложки: вытесняет её через сжатие, как компакт")
    func hudReplacesTuning() {
        var m = Self.model(.tuning(.width(-1)))
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(fx == [.cancel(.peekEnd), .animate(.shrink), Self.startGrow])
        #expect(m.pending == .hud(.volume, level: 0.5))
    }

    @Test("Уведомление важнее подложки: вытесняет её через сжатие, как компакт")
    func alertReplacesTuning() {
        var m = Self.model(.tuning(.height(2)))
        let charging = IslandAlert.charging(level: 0.5)
        let fx = IslandMachine.reduce(&m, .alertArrived(charging))
        #expect(fx == [.cancel(.peekEnd), .animate(.shrink), Self.startGrow])
        #expect(m.pending == .alert(charging))
    }

    @Test("Подложка во время сжатия к уведомлению: подложка становится целью, уведомление низкого приоритета теряется")
    func tuningDuringShrinkDropsLowPriorityAlert() {
        var m = Self.model(.shrink, media: true)
        m.pending = .alert(.charging(level: 0.5))
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.width(-1)))
        #expect(fx.isEmpty)
        #expect(m.pending == .tuning(.width(-1)))
        // Charging — приоритет 0: displaceByHUD его не возвращает в очередь (как в hudDuringShrinkDropsAlert)
        #expect(m.alertQueue.isEmpty)
    }

    @Test("Подложка во время сжатия к HUD: подложка становится новой целью")
    func tuningDuringShrinkToHUD() {
        var m = Self.model(.shrink, media: true)
        m.pending = .hud(.volume, level: 0.5)
        let fx = IslandMachine.reduce(&m, .tuningHintChanged(.height(0)))
        #expect(fx.isEmpty)
        #expect(m.pending == .tuning(.height(0)))
    }

    @Test("Строка громкости плеера сбрасывается, когда подложка морфится из раскрытого (reduce wrapper)")
    func volumeRowResetsOnTuning() {
        var m = Self.model(.expanded, media: true)
        m.expandedView = .player
        m.volumeRowShown = true
        _ = IslandMachine.reduce(&m, .tuningHintChanged(.width(1)))
        #expect(m.surface == .tuning(.width(1)))
        #expect(!m.volumeRowShown)
    }
}
