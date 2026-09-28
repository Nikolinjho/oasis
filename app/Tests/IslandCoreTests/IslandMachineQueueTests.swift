import Testing
@testable import IslandCore

/// Очередь уведомлений: приоритет, замена того же вида, показ следующего через сжатие
struct IslandMachineQueueTests {
    static let charging = IslandAlert.charging(level: 0.8)
    static let low = IslandAlert.lowBattery(level: 0.1)
    static let lowPower = IslandAlert.lowPower(level: 0.4)
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)
    static let hud = Surface.hud(.volume, level: 0.5)

    static func model(_ surface: Surface) -> IslandModel {
        var model = IslandModel(config: .alcove)
        model.surface = surface
        return model
    }

    @Test("Уведомление другого вида во время показа встаёт в очередь")
    func queuesDifferentKind() {
        var m = Self.model(.alert(Self.charging))
        #expect(IslandMachine.reduce(&m, .alertArrived(Self.low)).isEmpty)
        #expect(m.surface == .alert(Self.charging))
        #expect(m.alertQueue == [Self.low])
    }

    @Test("Очередь по приоритету, при равном — по приходу, тот же вид заменяет ждущее")
    func queueOrder() {
        var m = Self.model(.hud(.volume, level: 0.5))
        _ = IslandMachine.reduce(&m, .alertArrived(Self.charging))
        _ = IslandMachine.reduce(&m, .alertArrived(Self.lowPower))
        _ = IslandMachine.reduce(&m, .alertArrived(Self.low))
        #expect(m.alertQueue == [Self.low, Self.lowPower, Self.charging])
        _ = IslandMachine.reduce(&m, .alertArrived(.charging(level: 1)))
        #expect(m.alertQueue == [Self.low, Self.lowPower, .charging(level: 1)])
    }

    @Test("После уведомления следующее из очереди показывается через сжатие уведомления")
    func nextFromQueue() {
        var m = Self.model(.alert(Self.charging))
        m.alertQueue = [Self.low]
        let fx = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(fx == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(m.pending == .alert(Self.low))
        #expect(m.alertQueue.isEmpty)
    }

    @Test("Low Battery из покоя играет свой звук и держится 5 с")
    func lowBatterySound() {
        var m = Self.model(.idle)
        let fx = IslandMachine.reduce(&m, .alertArrived(Self.low))
        #expect(fx == [.animate(.alertIn), .schedule(.alertHide, after: .seconds(5)), .play(.lowBattery)])
    }

    @Test("Звук играет, когда уведомление появилось после сжатия, а не когда встало в очередь")
    func soundOnGrow() {
        var m = Self.model(.shrink)
        m.pending = .alert(Self.lowPower)
        let fx = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(fx == [.animate(.alertGrow), .schedule(.alertHide, after: .seconds(5)), .play(.lowPower)])
    }

    @Test("Сжатие уже идёт к уведомлению: другого вида встаёт в очередь, того же вида заменяет ожидаемое")
    func pendingAlertBranches() {
        var other = Self.model(.shrink)
        other.pending = .alert(Self.charging)
        #expect(IslandMachine.reduce(&other, .alertArrived(Self.low)).isEmpty)
        #expect(other.pending == .alert(Self.charging))
        #expect(other.alertQueue == [Self.low])

        var same = Self.model(.shrink)
        same.pending = .alert(Self.charging)
        let full = IslandAlert.charging(level: 1)
        #expect(IslandMachine.reduce(&same, .alertArrived(full)).isEmpty)
        #expect(same.pending == .alert(full))
        #expect(same.alertQueue.isEmpty)
    }

    @Test("hudHide показывает первое уведомление из очереди по приоритету, alertHide после него — следующее")
    func hudHideThenAlertHideShowsQueueInOrder() {
        var m = Self.model(Self.hud)
        _ = IslandMachine.reduce(&m, .alertArrived(Self.charging))
        _ = IslandMachine.reduce(&m, .alertArrived(Self.low))
        #expect(m.alertQueue == [Self.low, Self.charging])

        let fx1 = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(fx1 == [.cancel(.peekEnd), .animate(.shrinkFromWide), Self.startGrow])
        #expect(m.pending == .alert(Self.low))
        #expect(m.alertQueue == [Self.charging])

        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .alert(Self.low))

        let fx2 = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(fx2 == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(m.pending == .alert(Self.charging))
        #expect(m.alertQueue.isEmpty)
    }

    @Test("HUD во время сжатия к уведомлению отбрасывает только его: очередь остальных уведомлений остаётся")
    func hudDuringShrinkKeepsRestOfQueue() {
        var m = Self.model(.shrink)
        m.pending = .alert(Self.charging)
        m.alertQueue = [Self.low]
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)).isEmpty)
        #expect(m.pending == Self.hud)
        #expect(m.alertQueue == [Self.low])
    }

    @Test("Обновление уже показанного Low Battery новым уровнем не переигрывает звук")
    func alertUpdateHasNoSound() {
        var m = Self.model(.alert(Self.low))
        let updated = IslandAlert.lowBattery(level: 0.05)
        let fx = IslandMachine.reduce(&m, .alertArrived(updated))
        #expect(fx == [.animate(.alertUpdate), .schedule(.alertHide, after: updated.duration)])
    }

    @Test("Low Battery поверх раскрытого острова морфится и играет звук")
    func lowBatteryMorphsWithSound() {
        var m = Self.model(.expanded)
        let fx = IslandMachine.reduce(&m, .alertArrived(Self.low))
        #expect(fx == [.animate(.hudMorph), .schedule(.alertHide, after: Self.low.duration), .play(.lowBattery)])
    }
}
