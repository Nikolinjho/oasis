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
        let reminder = CalendarReminder(eventID: "call", title: "Созвон", minutes: 15, color: Self.event.color)
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

    @Test("Проснулись через 30 с после начала: сначала компакт календаря, поверх — peek старта")
    func wakeAfterStartShowsPeek() {
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-200))
        clock.update(agenda: Self.agenda, now: Self.at(-200))
        #expect(store.model.surface == .idle)
        clock.tick(now: Self.at(30))
        #expect(store.model.surface == .calendarPeek)
        #expect(store.calendarEvent == Self.event)
    }

    @Test("Событие начинается внутри идущего: окно и peek старта переходят к нему")
    func overlappingEventTakesWindow() {
        let long = CalendarEvent(
            id: "long", title: "Длинное", start: Self.start, end: Self.at(3600), isAllDay: false, color: Self.event.color)
        let inner = CalendarEvent(
            id: "inner", title: "Внутри", start: Self.at(1800), end: Self.at(2700), isAllDay: false, color: Self.event.color)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(10))
        clock.update(agenda: DayAgenda.make(events: [long, inner], now: Self.at(10)), now: Self.at(10))
        #expect(store.calendarEvent == long)
        clock.tick(now: Self.at(1745))
        #expect(store.calendarEvent == inner)
        clock.tick(now: Self.at(1800))
        #expect(store.model.surface == .calendarPeek)
        #expect(store.calendarEvent == inner)
    }

    @Test("Правка события внутри окна (название, конец) доходит до store")
    func editedLiveEventReachesStore() {
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-100))
        clock.update(agenda: Self.agenda, now: Self.at(-30))
        var edited = Self.event
        edited.title = "Созвон перенесли"
        edited.end = Self.at(2400)
        clock.update(agenda: DayAgenda(today: [edited], tomorrow: []), now: Self.at(-20))
        #expect(store.calendarEvent == edited)
    }

    @Test("Напоминания двух событий в один тик: первое на экране, второе ждёт в очереди")
    func twoRemindersInOneTick() {
        let later = CalendarEvent(
            id: "later", title: "Потом", start: Self.at(600), end: Self.at(1800), isAllDay: false, color: Self.event.color)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-301))
        clock.update(agenda: DayAgenda(today: [Self.event, later], tomorrow: []), now: Self.at(-300))
        let first = IslandAlert.calendarReminder(CalendarReminder(eventID: "call", title: "Созвон", minutes: 5, color: Self.event.color))
        let second = IslandAlert.calendarReminder(CalendarReminder(eventID: "later", title: "Потом", minutes: 15, color: Self.event.color))
        #expect(store.model.surface == .alert(first))
        #expect(store.model.alertQueue == [second])
    }

    @Test("Смена системного времени будит часы сразу, не дожидаясь таймера")
    func clockChangeWakesClock() async {
        let now = Date()
        let event = CalendarEvent(
            id: "soon", title: "Скоро", start: now.addingTimeInterval(30), end: now.addingTimeInterval(600),
            isAllDay: false, color: Self.event.color)
        let store = IslandStore(config: .alcove)
        // часы думают, что сейчас час назад: окно ещё закрыто, таймер — через 5 минут
        let clock = CalendarClock(store: store, start: now.addingTimeInterval(-3600))
        clock.update(agenda: DayAgenda(today: [event], tomorrow: []), now: now.addingTimeInterval(-3600))
        #expect(store.calendarEvent == nil)
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        for _ in 0..<50 where store.calendarEvent == nil { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(store.calendarEvent == event)
        _ = clock
    }
}
