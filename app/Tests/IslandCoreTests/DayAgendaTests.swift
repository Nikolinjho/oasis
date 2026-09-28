import Foundation
import Testing
@testable import IslandCore

struct DayAgendaTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    static func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, start: start, end: end, isAllDay: allDay, color: RGB(red: 0, green: 1, blue: 0))
    }

    static let now = at(26, 23, 10)

    @Test("Сегодня: только не закончившиеся, по началу, без событий на весь день")
    func today() {
        let agenda = DayAgenda.make(events: [
            Self.event("later", Self.at(26, 23, 40), Self.at(26, 23, 50)),
            Self.event("past", Self.at(26, 10), Self.at(26, 11)),
            Self.event("running", Self.at(26, 23, 5), Self.at(26, 23, 30)),
            Self.event("all-day", Self.at(26, 0), Self.at(27, 0), allDay: true),
        ], now: Self.now, calendar: Self.calendar)
        #expect(agenda.today.map(\.id) == ["running", "later"])
    }

    @Test("Завтра — отдельный список, послезавтра не попадает")
    func tomorrow() {
        let agenda = DayAgenda.make(events: [
            Self.event("tomorrow", Self.at(27, 9), Self.at(27, 10)),
            Self.event("after", Self.at(28, 9), Self.at(28, 10)),
        ], now: Self.now, calendar: Self.calendar)
        #expect(agenda.today.isEmpty)
        #expect(agenda.tomorrow.map(\.id) == ["tomorrow"])
    }

    @Test("Текущее событие — первое не закончившееся к моменту")
    func current() {
        let agenda = DayAgenda.make(events: [
            Self.event("running", Self.at(26, 23, 5), Self.at(26, 23, 30)),
            Self.event("later", Self.at(26, 23, 40), Self.at(26, 23, 50)),
        ], now: Self.now, calendar: Self.calendar)
        #expect(agenda.current(at: Self.now)?.id == "running")
        #expect(agenda.current(at: Self.at(26, 23, 35))?.id == "later")
        #expect(agenda.current(at: Self.at(26, 23, 55)) == nil)
    }

    @Test("Окно календаря открыто: карточка Duo — событие окна (как компакт и меню), а не первое не закончившееся")
    func currentPrefersLiveEvent() {
        let long = Self.event("long", Self.at(26, 22), Self.at(26, 23, 30))
        let inner = Self.event("inner", Self.at(26, 23, 5), Self.at(26, 23, 20))
        let agenda = DayAgenda.make(events: [long, inner], now: Self.now, calendar: Self.calendar)
        #expect(agenda.current(at: Self.now)?.id == "long")
        #expect(agenda.current(at: Self.now, live: inner)?.id == "inner")
        // окно закрыто: прежнее правило
        #expect(agenda.current(at: Self.now, live: nil)?.id == "long")
    }
}
