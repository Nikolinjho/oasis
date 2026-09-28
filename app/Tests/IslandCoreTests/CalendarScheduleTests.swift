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

    @Test("Окно календаря: с минуты до начала до конца события")
    func liveWindow() {
        #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-61)) == nil)
        #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-60)) == Self.event)
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

    @Test("Следующая граница — ближайшая из напоминаний, T−1, старта и конца")
    func nextBoundary() {
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-2000)) == Self.at(-900))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-200)) == Self.at(-60))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-30)) == Self.at(0))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(10)) == Self.at(1800))
        #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(1800)) == nil)
    }
}
