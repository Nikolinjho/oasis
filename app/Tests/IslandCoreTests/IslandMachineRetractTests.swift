import Testing
@testable import IslandCore

/// Отзыв уведомления (Dismiss Event): ждущие в очереди и то, к которому идёт сжатие, уходят, показанное дослуживает свой срок
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

    @Test("Показанное напоминание дослуживает свой срок: таймер alertHide не трогаем")
    func keepsVisible() {
        var m = Self.model(.alert(Self.reminder("a", 5)), queue: [Self.low])
        #expect(IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a"))).isEmpty)
        #expect(m.surface == .alert(Self.reminder("a", 5)))
        #expect(m.alertQueue == [Self.low])
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
