import Testing
@testable import IslandCore

/// Отзыв уведомления (Dismiss Event): ждущие в очереди уходят, показанное дослуживает свой срок
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

    @Test("Напоминание, к которому уже идёт сжатие, тоже дослуживает: оно фактически показывается")
    func keepsPending() {
        var m = Self.model(.shrink)
        m.pending = .alert(Self.reminder("a", 15))
        #expect(IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "a"))).isEmpty)
        #expect(m.pending == .alert(Self.reminder("a", 15)))
    }

    @Test("Без ждущих этого вида ничего не меняется")
    func noop() {
        var m = Self.model(.calendar, queue: [Self.low])
        let before = m
        #expect(IslandMachine.reduce(&m, .alertRetracted(.calendarReminder(eventID: "zzz"))).isEmpty)
        #expect(m == before)
    }
}
