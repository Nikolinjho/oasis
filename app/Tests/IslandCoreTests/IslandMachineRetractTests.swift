import Testing
@testable import IslandCore

/// Отзыв уведомления (Dismiss Event): ждущие в очереди, то, к которому идёт сжатие, и показанное уходят
struct IslandMachineRetractTests {
    static let color = RGB(red: 0.2, green: 0.5, blue: 1)
    static func reminder(_ id: String, _ minutes: Int) -> IslandAlert {
        .calendarReminder(CalendarReminder(eventID: id, title: id, minutes: minutes, color: color))
    }
    static let low = IslandAlert.lowBattery(level: 0.1)

    static func model(_ surface: Surface, queue: [IslandAlert] = []) -> IslandModel {
        var model = IslandModel(config: .alcove)
        model.surface = surface
        model.alertQueue = queue
        return model
    }

    @Test("Ждущее напоминание отклонённого события уходит из очереди, остальные остаются")
    func removesQueued() {
        var m = Self.model(.alert(Self.low), queue: [Self.reminder("a", 5), Self.reminder("b", 15)])
        let fx = IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a")))
        #expect(fx.isEmpty)
        #expect(m.alertQueue == [Self.reminder("b", 15)])
        #expect(m.surface == .alert(Self.low))
    }

    @Test("Отзыв показанного: уходит сразу в следующее из очереди, таймер alertHide снят")
    func shownGoesToNextQueued() {
        var m = Self.model(.alert(Self.reminder("a", 5)), queue: [Self.low])
        let fx = IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a")))
        #expect(fx == [.cancel(.alertHide), .cancel(.peekEnd), .animate(.alertShrink), .schedule(.grow, after: IslandTiming.shrink)])
        #expect(m.pending == .alert(Self.low))
        #expect(m.alertQueue.isEmpty)
    }

    @Test("Отзыв показанного без очереди: уходит сразу в покой")
    func shownGoesToRest() {
        var idle = Self.model(.alert(Self.reminder("a", 5)))
        #expect(IslandMachine.reduce(&idle, .alertRetracted(.calendarReminder(eventID: "a"))) == [.cancel(.alertHide), .animate(.alertOut)])
        #expect(idle.surface == .idle)

        var live = Self.model(.alert(Self.reminder("a", 5)))
        live.calendarLive = true
        _ = IslandMachine.reduce(&live, .alertRetracted(.calendarReminder(eventID: "a")))
        #expect(live.pending == .calendar)
    }

    @Test("Отзыв показанного, затем HUD, затем hudHide: покой, очередь пустая")
    func shownRetractedThenHUD() {
        let reminder = Self.reminder("a", 5)
        var m = Self.model(.alert(reminder))
        _ = IslandMachine.reduce(&m, .alertRetracted(reminder.kind))
        _ = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(m.alertQueue.isEmpty)
        #expect(m.heardAlerts.isEmpty)
        _ = IslandMachine.reduce(&m, .timerFired(.hudHide))
        #expect(m.surface == .idle)
        #expect(m.alertQueue.isEmpty)
    }

    @Test("Сжатие шло к напоминанию отклонённого события: вместо него покой, после grow ни напоминания, ни звука")
    func pendingGoesToRest() {
        var m = Self.model(.shrink)
        m.hasMedia = true
        m.pending = .alert(Self.reminder("a", 15))
        #expect(IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a"))).isEmpty)
        #expect(m.pending == .compact)
        let fx = IslandMachine.reduce(&m, .timerFired(.grow))
        #expect(fx == [.animate(.grow)])
        #expect(m.surface == .compact)
    }

    @Test("Сжатие шло к напоминанию отклонённого события, в очереди есть другое: сжатие идёт к следующему")
    func pendingGoesToNextQueued() {
        var m = Self.model(.shrink, queue: [Self.low])
        m.pending = .alert(Self.reminder("a", 15))
        _ = IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a")))
        #expect(m.pending == .alert(Self.low))
        #expect(m.alertQueue.isEmpty)
    }

    @Test("Сжатие к напоминанию другого события отзыв не трогает")
    func pendingOfOtherEventStays() {
        var m = Self.model(.shrink)
        m.pending = .alert(Self.reminder("b", 5))
        _ = IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a")))
        #expect(m.pending == .alert(Self.reminder("b", 5)))
    }

    @Test("Без ждущих этого вида ничего не меняется")
    func noop() {
        var m = Self.model(.calendar, queue: [Self.low])
        let before = m
        #expect(IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "zzz"))).isEmpty)
        #expect(m == before)
    }
}
