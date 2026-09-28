import Testing
@testable import IslandCore

/// Очередь уведомлений: приоритет, замена того же вида, показ следующего через сжатие
struct IslandMachineQueueTests {
    static let charging = IslandAlert.charging(level: 0.8)
    static let low = IslandAlert.lowBattery(level: 0.1)
    static let lowPower = IslandAlert.lowPower(level: 0.4)
    static let startGrow = IslandEffect.schedule(.grow, after: IslandTiming.shrink)

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
}
