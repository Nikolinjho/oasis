import Foundation
import Testing
@testable import IslandCore

struct CalendarScheduleTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let event = CalendarEvent(
        id: "call", title: "Созвон", start: start, end: start.addingTimeInterval(1800), isAllDay: false,
        color: RGB(red: 0.2, green: 0.5, blue: 1))
    static let agenda = DayAgenda(today: [event], tomorrow: [])

    static func at(_ offset: TimeInterval) -> Date { start.addingTimeInterval(offset) }

    @Test("Окно календаря: за 15 минут до начала до конца события (Time before event у Alcove 1.7.9)")
    func liveWindow() {
        #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-901)) == nil)
        #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-900)) == Self.event)
        #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(1799)) == Self.event)
        #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(1800)) == nil)
    }

    @Test("Напоминания за 15 и 5 минут и старт срабатывают при переходе через отметку")
    func crossings() {
        #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-901), to: Self.at(-899)) == [.reminder(Self.event, minutes: 15)])
        #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-301), to: Self.at(-300)) == [.reminder(Self.event, minutes: 5)])
        #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-1), to: Self.at(0)) == [.started(Self.event)])
        #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-200), to: Self.at(-100)).isEmpty)
    }

    @Test("После сна отметки старше минуты не показываются")
    func staleMarks() {
        #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-1000), to: Self.at(-200)).isEmpty)
        #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-1000), to: Self.at(-250)) == [.reminder(Self.event, minutes: 5)])
    }

    @Test("Следующая граница — ближайшая из напоминаний, окна T−15, старта и конца")
    func nextBoundary() {
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-2000)) == Self.at(-900))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(0)) == Self.at(1800))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-30)) == Self.at(0))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(10)) == Self.at(1800))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(1800)) == nil)
    }

    @Test("Пересекающиеся события: окно переходит к начавшемуся позже, после его конца — обратно")
    func overlappingLiveEvent() {
        let long = CalendarEvent(
            id: "long", title: "Длинное", start: Self.start, end: Self.at(3600), isAllDay: false, color: Self.event.color)
        let inner = CalendarEvent(
            id: "inner", title: "Внутри", start: Self.at(1800), end: Self.at(2700), isAllDay: false, color: Self.event.color)
        let agenda = DayAgenda.make(events: [inner, long], now: Self.at(-100))
        #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(899)) == long)
        #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(900)) == inner)
        #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(2000)) == inner)
        #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(2700)) == long)
    }

    @Test("Событие завтра в начале суток: напоминание, граница и окно работают ещё до полуночи")
    func tomorrowEvent() {
        let agenda = DayAgenda(today: [], tomorrow: [Self.event])
        #expect(CalendarSchedule.crossings(in: agenda, from: Self.at(-901), to: Self.at(-899)) == [.reminder(Self.event, minutes: 15)])
        #expect(CalendarSchedule.nextBoundary(in: agenda, after: Self.at(-2000)) == Self.at(-900))
        #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(-30)) == Self.event)
    }
}
