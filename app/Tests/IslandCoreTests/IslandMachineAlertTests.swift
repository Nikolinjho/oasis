import Testing
@testable import IslandCore

/// Уведомления (Charging, в P1 батарея, AirPods, календарь): режим Alcove, темп 1
struct IslandMachineAlertTests {
    static let charging = IslandAlert.charging(level: 0.51)
    static let hideAlert = IslandEffect.schedule(.alertHide, after: IslandTiming.alertVisible)
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)
    static let hud = Surface.hud(.volume, level: 0.5)

    static func model(_ surface: Surface, media: Bool = false) -> IslandModel {
        var model = IslandModel(config: .alcove)
        model.surface = surface
        model.hasMedia = media
        return model
    }

    @Test("Из покоя уведомление раскрывается сразу и держится 5 с")
    func fromIdle() {
        var m = Self.model(.idle)
        let fx = IslandMachine.reduce(&m, .alertArrived(Self.charging))
        #expect(m.surface == .alert(Self.charging))
        #expect(fx == [.animate(.alertIn), Self.hideAlert])
    }

    @Test("Из компакта — через сжатие, раскрытие пружиной Charging")
    func fromCompact() {
        var m = Self.model(.compact, media: true)
        #expect(IslandMachine.reduce(&m, .alertArrived(Self.charging)) == [.cancel(.peekEnd), .animate(.shrink), Self.startGrow])
        #expect(m.pending == .alert(Self.charging))
        let fx = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .alert(Self.charging))
        #expect(fx == [.animate(.alertGrow), Self.hideAlert])
    }

    @Test("Конец уведомления при музыке: сжатие пружиной Charging и обратно в компакт")
    func hidesToCompact() {
        var m = Self.model(.alert(Self.charging), media: true)
        let fx = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(fx == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(m.pending == .compact)
    }

    @Test("Конец уведомления без музыки: уход в покой")
    func hidesToIdle() {
        var m = Self.model(.alert(Self.charging))
        let fx = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(m.surface == .idle)
        #expect(fx == [.animate(.alertOut)])
    }

    @Test("Раскрытый морфится в уведомление, как в HUD", arguments: [Surface.expanded, .hover])
    func morphsFromExpanded(from: Surface) {
        var m = Self.model(from, media: true)
        let fx = IslandMachine.reduce(&m, .alertArrived(Self.charging))
        #expect(m.surface == .alert(Self.charging))
        #expect(fx == [.animate(.hudMorph), Self.hideAlert])
    }

    @Test("Во время HUD уведомление ждёт, после HUD показывается через сжатие")
    func waitsForHUD() {
        var m = Self.model(Self.hud)
        #expect(IslandMachine.reduce(&m, .alertArrived(Self.charging)).isEmpty)
        #expect(m.queuedAlert == Self.charging)
        let fx = IslandMachine.reduce(&m, .timerFired(.hudHide))
        // из широкого HUD — пружина широкого сжатия
        #expect(fx == [.cancel(.peekEnd), .animate(.shrinkFromWide), Self.startGrow])
        #expect(m.pending == .alert(Self.charging))
        #expect(m.queuedAlert == nil)
    }

    @Test("HUD важнее уведомления: вытесняет его через сжатие")
    func hudReplacesAlert() {
        var m = Self.model(.alert(Self.charging))
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        // сжатие из уведомления — его пружина (замер Charging → сжатие)
        #expect(fx == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(m.pending == Self.hud)
    }

    @Test("Новое уведомление поверх текущего меняет содержимое и продлевает показ")
    func replacesAlert() {
        var m = Self.model(.alert(Self.charging))
        let full = IslandAlert.charging(level: 1)
        let fx = IslandMachine.reduce(&m, .alertArrived(full))
        #expect(m.surface == .alert(full))
        #expect(fx == [.animate(.alertUpdate), Self.hideAlert])
    }

    @Test("HUD во время сжатия к уведомлению: HUD раскрывается первым, уведомление ждёт")
    func hudDuringShrinkQueuesAlert() {
        var m = Self.model(.shrink, media: true)
        m.pending = .alert(Self.charging)
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)).isEmpty)
        #expect(m.pending == Self.hud)
        #expect(m.queuedAlert == Self.charging)
    }
}
