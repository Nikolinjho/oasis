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
        #expect(m.alertQueue == [Self.charging])
        let fx = IslandMachine.reduce(&m, .timerFired(.hudHide))
        // из широкого HUD — пружина широкого сжатия
        #expect(fx == [.cancel(.peekEnd), .animate(.shrinkFromWide), Self.startGrow])
        #expect(m.pending == .alert(Self.charging))
        #expect(m.alertQueue.isEmpty)
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

    @Test("HUD во время сжатия к Charging: HUD раскрывается первым, Charging (приоритет 0) отбрасывается")
    func hudDuringShrinkDropsAlert() {
        var m = Self.model(.shrink, media: true)
        m.pending = .alert(Self.charging)
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)).isEmpty)
        #expect(m.pending == Self.hud)
        #expect(m.alertQueue.isEmpty)
    }

    @Test("Уведомление во время отклика на hover: раскрытие отменяется, дальше — как из исходного состояния")
    func duringHoverNudge() {
        var m = Self.model(.hoverNudge(from: .idle))
        let fx = IslandMachine.reduce(&m, .alertArrived(Self.charging))
        #expect(fx == [.cancel(.hoverOpen), .animate(.alertIn), Self.hideAlert])
        #expect(m.surface == .alert(Self.charging))
    }

    @Test("Уведомление, пока курсор ушёл из раскрытого и ждёт схлопывания: таймер отменяется, дальше — морф")
    func duringLeaving() {
        var m = Self.model(.hover, media: true)
        m.leaving = true
        let fx = IslandMachine.reduce(&m, .alertArrived(Self.charging))
        #expect(fx == [.cancel(.hoverLeave), .animate(.hudMorph), Self.hideAlert])
        #expect(m.surface == .alert(Self.charging))
    }

    @Test("HUD вытесняет уведомление A; когда потом B сжимается к новому уведомлению, устаревший alertHide от A не мешает: guard требует .alert, а сжатие уже .shrink")
    func staleAlertHideAfterHUDReplacesAlert() {
        var m = Self.model(.alert(Self.charging), media: true)
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(m.surface == .shrink)
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == Self.hud)
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.surface == .shrink)
        #expect(m.pending == .compact)
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .compact)
        let full = IslandAlert.charging(level: 1)
        _ = IslandMachine.reduce(&m, .alertArrived(full))
        #expect(m.surface == .shrink)
        #expect(m.pending == .alert(full))
        // устаревший таймер конца уведомления A: сжатие уже идёт к B, guard требует .alert
        let fx = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(fx.isEmpty)
        #expect(m.surface == .shrink)
        #expect(m.pending == .alert(full))
    }

    @Test("Музыка кончилась во время уведомления: alertHide уводит в покой, а не в компакт")
    func mediaClearedDuringAlert() {
        var m = Self.model(.alert(Self.charging), media: true)
        _ = IslandMachine.reduce(&m, .mediaCleared)
        #expect(m.hasMedia == false)
        let fx = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(m.surface == .idle)
        #expect(fx == [.animate(.alertOut)])
    }

    @Test("AirPods: приоритет 1, 5 с, без звука")
    func airpodsAlert() {
        let airpods = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 1))
        #expect(airpods.kind == .airpods)
        #expect(airpods.priority == 1)
        #expect(airpods.duration == .seconds(5))
        #expect(airpods.sound == nil)
    }

    @Test("AirPods поверх компакта календаря: сжатие, 5 с без звука, затем сжатие обратно в календарь")
    func airpodsOverCalendar() {
        let airpods = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 1))
        var m = Self.model(.calendar)
        m.calendarLive = true
        #expect(IslandMachine.reduce(&m, .alertArrived(airpods)) == [.cancel(.peekEnd), .animate(.shrink), Self.startGrow])
        #expect(m.pending == .alert(airpods))
        #expect(IslandMachine.reduce(&m, .timerFired(.grow)) == [.animate(.alertGrow), Self.hideAlert])
        #expect(m.surface == .alert(airpods))
        #expect(IslandMachine.reduce(&m, .timerFired(.alertHide)) == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(m.pending == .calendar)
    }
}
