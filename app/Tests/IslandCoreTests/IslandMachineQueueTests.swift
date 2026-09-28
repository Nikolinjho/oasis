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

    @Test("Напоминание календаря: приоритет 2, держится 4.2 с, звук события")
    func reminderAlert() {
        let reminder = IslandAlert.calendarReminder(CalendarReminder(eventID: "call", title: "Созвон", minutes: 5, color: RGB(red: 0.2, green: 0.5, blue: 1)))
        #expect(reminder.kind == .calendarReminder(eventID: "call"))
        #expect(reminder.priority == 2)
        #expect(reminder.duration == .milliseconds(4200))
        #expect(reminder.sound == .event)
    }

    static func reminder(_ eventID: String, minutes: Int) -> IslandAlert {
        .calendarReminder(CalendarReminder(eventID: eventID, title: eventID, minutes: minutes, color: RGB(red: 0.2, green: 0.5, blue: 1)))
    }

    @Test("Напоминания разных событий в один тик показываются по очереди, а не заменяют друг друга")
    func remindersOfDifferentEventsQueue() {
        var m = Self.model(.idle)
        _ = IslandMachine.reduce(&m, .alertArrived(Self.reminder("first", minutes: 5)))
        #expect(IslandMachine.reduce(&m, .alertArrived(Self.reminder("second", minutes: 15))).isEmpty)
        #expect(m.surface == .alert(Self.reminder("first", minutes: 5)))
        #expect(m.alertQueue == [Self.reminder("second", minutes: 15)])
        // в очереди тоже: напоминание третьего события не вытесняет второе
        _ = IslandMachine.reduce(&m, .alertArrived(Self.reminder("third", minutes: 15)))
        #expect(m.alertQueue == [Self.reminder("second", minutes: 15), Self.reminder("third", minutes: 15)])
    }

    @Test("Напоминание того же события обновляет показанное: за 5 минут вместо за 15")
    func reminderOfSameEventUpdates() {
        var m = Self.model(.alert(Self.reminder("call", minutes: 15)))
        let next = Self.reminder("call", minutes: 5)
        let fx = IslandMachine.reduce(&m, .alertArrived(next))
        #expect(m.surface == .alert(next))
        #expect(fx == [.animate(.alertUpdate), .schedule(.alertHide, after: next.duration)])
    }

    // MARK: HUD вытесняет уведомление (решение по ревью P1): приоритет 2 и выше возвращается в очередь

    @Test("HUD вытесняет показанное напоминание: оно уходит в очередь и показывается после hudHide без повторного звука")
    func hudRequeuesShownReminder() {
        let reminder = Self.reminder("call", minutes: 5)
        var m = Self.model(.alert(reminder))
        let fx = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(fx == [.cancel(.peekEnd), .animate(.alertShrink), Self.startGrow])
        #expect(m.pending == Self.hud)
        #expect(m.alertQueue == [reminder])

        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == Self.hud)
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.pending == .alert(reminder))
        #expect(m.alertQueue.isEmpty)
        // звук напоминания уже прозвучал до HUD: второй раз не играет
        let grow = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .alert(reminder))
        #expect(grow == [.animate(.alertGrow), .schedule(.alertHide, after: reminder.duration)])
    }

    @Test("HUD во время сжатия к Low Battery: оно уходит в очередь и показывается после hudHide со звуком")
    func hudRequeuesPendingLowBattery() {
        var m = Self.model(.shrink)
        m.pending = .alert(Self.low)
        m.alertQueue = [Self.lowPower]
        #expect(IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5)).isEmpty)
        #expect(m.pending == Self.hud)
        // по приоритету: Low Battery (2) впереди Low Power (1)
        #expect(m.alertQueue == [Self.low, Self.lowPower])

        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.pending == .alert(Self.low))
        // до HUD уведомление не успело показаться: звук играет при первом показе
        let grow = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(grow == [.animate(.alertGrow), .schedule(.alertHide, after: Self.low.duration), .play(.lowBattery)])
    }

    @Test("Вытесненное HUD уведомление приоритета ниже 2 пропадает, как в P0", arguments: [
        IslandAlert.charging(level: 0.8), .lowPower(level: 0.4), .airpods(AirPodsInfo(name: "AirPods", battery: 0.5)),
    ])
    func hudDropsLowPriority(_ alert: IslandAlert) {
        var shown = Self.model(.alert(alert))
        _ = IslandMachine.reduce(&shown, .hudChanged(.volume, level: 0.5))
        #expect(shown.alertQueue.isEmpty)

        var pending = Self.model(.shrink)
        pending.pending = .alert(alert)
        _ = IslandMachine.reduce(&pending, .hudChanged(.volume, level: 0.5))
        #expect(pending.alertQueue.isEmpty)
    }

    @Test("Вернувшееся в очередь напоминание заменяется новым того же события и встаёт по приоритету")
    func requeuedReminderReplacedBySameKind() {
        let early = Self.reminder("call", minutes: 15)
        var m = Self.model(.alert(early))
        m.alertQueue = [Self.lowPower]
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(m.alertQueue == [early, Self.lowPower])
        let late = Self.reminder("call", minutes: 5)
        _ = IslandMachine.reduce(&m, .alertArrived(late))
        #expect(m.alertQueue == [late, Self.lowPower])
        // новое напоминание — новый показ: звук играет
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        let grow = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(grow == [.animate(.alertGrow), .schedule(.alertHide, after: late.duration), .play(.event)])
    }

    @Test("Вернувшееся в очередь напоминание отклонённого события отзывается: после HUD — покой")
    func requeuedReminderIsRetractable() {
        let reminder = Self.reminder("call", minutes: 5)
        var m = Self.model(.alert(reminder))
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        _ = IslandMachine.reduce(&m, .alertRetracted(reminder.kind))
        #expect(m.alertQueue.isEmpty)
        #expect(m.heardAlerts.isEmpty)
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        let fx = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(fx == [.animate(.hudOut)])
        #expect(m.surface == .idle)
    }

    @Test("Окно календаря открыто: напоминание после HUD, затем возврат в компакт календаря")
    func requeuedReminderReturnsToCalendarCompact() {
        let reminder = Self.reminder("next", minutes: 5)
        var m = Self.model(.alert(reminder))
        m.calendarLive = true
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.pending == .alert(reminder))
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .alert(reminder))
        _ = IslandMachine.reduce(&m, .timerFired(.alertHide))
        #expect(m.pending == .calendar)
        _ = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(m.surface == .calendar)
    }
}
