import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

@MainActor
struct CalendarClockTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let event = CalendarEvent(
        id: "call", title: "Созвон", start: start, end: start.addingTimeInterval(1800), isAllDay: false,
        color: RGB(red: 0.2, green: 0.5, blue: 1))
    static let agenda = DayAgenda(today: [event], tomorrow: [])

    static func at(_ offset: TimeInterval) -> Date { start.addingTimeInterval(offset) }

    @Test("Переход через T−15 шлёт в store напоминание «Созвон» за 15 минут")
    func reminderReachesStore() {
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-901))
        clock.update(agenda: Self.agenda, now: Self.at(-899))
        let reminder = CalendarReminder(title: "Созвон", minutes: 15, color: Self.event.color)
        #expect(store.model.surface == .alert(.calendarReminder(reminder)))
        #expect(store.calendarEvent == nil)
    }

    @Test("С минуты до начала store получает событие окна календаря, после конца окно закрывается")
    func liveWindowReachesStore() {
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-100))
        clock.update(agenda: Self.agenda, now: Self.at(-30))
        #expect(store.calendarEvent == Self.event)
        #expect(store.model.calendarLive)
        clock.tick(now: Self.at(1800))
        #expect(!store.model.calendarLive)
    }
}
