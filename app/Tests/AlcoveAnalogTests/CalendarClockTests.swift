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

    @Test("Два события с общим началом: один старт за тик, звук события один раз")
    func commonStartPlaysOnce() {
        let twin = CalendarEvent(
            id: "twin", title: "Второе", start: Self.start, end: Self.at(900), isAllDay: false, color: Self.event.color)
        let store = IslandStore(config: .alcove)
        var sounds: [IslandSound] = []
        store.onSound = { sounds.append($0) }
        let clock = CalendarClock(store: store, start: Self.at(-30))
        clock.update(agenda: DayAgenda.make(events: [Self.event, twin], now: Self.at(-30)), now: Self.at(-30))
        clock.tick(now: Self.at(1))
        #expect(sounds == [.event])
        #expect(store.model.surface == .calendarPeek)
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

@MainActor
struct CalendarClockDismissTests {
    static let start = CalendarClockTests.start
    static func at(_ offset: TimeInterval) -> Date { CalendarClockTests.at(offset) }
    static func event(_ id: String, startsAt offset: TimeInterval) -> CalendarEvent {
        CalendarEvent(
            id: id, title: id, start: at(offset), end: at(offset + 1800), isAllDay: false,
            color: CalendarClockTests.event.color)
    }

    @Test("Отклонённое событие не шлёт напоминаний и старта, следующее — шлёт")
    func dismissedHasNoReminders() {
        let first = Self.event("first", startsAt: 0)
        let second = Self.event("second", startsAt: 1200)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-600))
        clock.update(agenda: DayAgenda(today: [first, second], tomorrow: []), now: Self.at(-600))
        clock.dismiss("first", now: Self.at(-600))

        // T−5 отклонённого: тишина
        clock.tick(now: Self.at(-299))
        #expect(store.model.surface == .idle)
        // старт отклонённого: ни компакта, ни peek, ни пунктов меню
        clock.tick(now: Self.at(1))
        #expect(store.model.surface == .idle)
        #expect(!store.model.calendarLive)
        #expect(clock.menuModel(now: Self.at(1)) == nil)

        // T−15 следующего приходит, пункты меню — по нему
        clock.tick(now: Self.at(301))
        let reminder = CalendarReminder(eventID: "second", title: "second", minutes: 15, color: second.color)
        #expect(store.model.surface == .alert(.calendarReminder(reminder)))
        #expect(clock.menuModel(now: Self.at(301))?.event.id == "second")
    }

    @Test("Отклонённое идущее событие отдаёт окно следующему")
    func dismissLiveKeepsNext() {
        let first = Self.event("first", startsAt: 0)
        let second = Self.event("second", startsAt: 600)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(10))
        clock.update(agenda: DayAgenda(today: [first, second], tomorrow: []), now: Self.at(10))
        #expect(store.calendarEvent == first)
        clock.dismiss("first", now: Self.at(10))
        #expect(!store.model.calendarLive)
        clock.tick(now: Self.at(550))
        #expect(store.calendarEvent == second)
    }

    @Test("Отклонённое завтрашнее событие тоже отклонено: напоминание накануне не приходит")
    func dismissTomorrow() {
        let night = Self.event("night", startsAt: 600)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-60))
        clock.update(agenda: DayAgenda(today: [], tomorrow: [night]), now: Self.at(-60))
        #expect(clock.menuModel(now: Self.at(-60))?.event.id == "night")
        clock.dismiss("night", now: Self.at(-60))
        clock.tick(now: Self.at(301))
        #expect(store.model.surface == .idle)
        #expect(clock.menuModel(now: Self.at(301)) == nil)
    }

    @Test("Отклонение переживает обновление agenda и забывается, когда события в agenda нет")
    func dismissedSurvivesUpdates() {
        let first = Self.event("first", startsAt: 300)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(0))
        clock.update(agenda: DayAgenda(today: [first], tomorrow: []), now: Self.at(0))
        clock.dismiss("first", now: Self.at(0))
        // полночь: событие переехало из завтра в сегодня — всё ещё отклонено
        clock.update(agenda: DayAgenda(today: [], tomorrow: [first]), now: Self.at(1))
        clock.update(agenda: DayAgenda(today: [first], tomorrow: []), now: Self.at(2))
        #expect(clock.menuModel(now: Self.at(2)) == nil)
        // событие пропало из agenda и вернулось: отклонение забыто
        clock.update(agenda: .empty, now: Self.at(3))
        clock.update(agenda: DayAgenda(today: [first], tomorrow: []), now: Self.at(4))
        #expect(clock.menuModel(now: Self.at(4))?.event.id == "first")
    }

    @Test("Пересечение событий: меню по событию компакта, Dismiss из меню убирает именно его")
    func menuFollowsCompact() {
        let long = CalendarEvent(
            id: "long", title: "long", start: Self.at(0), end: Self.at(3600), isAllDay: false, color: CalendarClockTests.event.color)
        let inner = CalendarEvent(
            id: "inner", title: "inner", start: Self.at(1800), end: Self.at(2700), isAllDay: false, color: long.color)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-600))
        clock.update(agenda: DayAgenda.make(events: [long, inner], now: Self.at(-600)), now: Self.at(-600))
        // окно ещё закрыто: самое раннее из T−15…конец
        #expect(clock.menuModel(now: Self.at(-600))?.event.id == "long")

        clock.tick(now: Self.at(1790))
        #expect(store.calendarEvent == inner)
        #expect(clock.menuModel(now: Self.at(1790))?.event.id == "inner")

        clock.dismiss(try! #require(clock.menuModel(now: Self.at(1790))).event.id, now: Self.at(1790))
        #expect(store.calendarEvent == long)
        #expect(store.model.calendarLive)
        #expect(clock.menuModel(now: Self.at(1790))?.event.id == "long")
    }

    @Test("Dismiss убирает ждущее в очереди напоминание события, показанное напоминание другого события остаётся")
    func dismissRetractsQueuedReminder() {
        let first = Self.event("call", startsAt: 0)
        let later = Self.event("later", startsAt: 600)
        let store = IslandStore(config: .alcove)
        let clock = CalendarClock(store: store, start: Self.at(-301))
        clock.update(agenda: DayAgenda(today: [first, later], tomorrow: []), now: Self.at(-300))
        let shown = IslandAlert.calendarReminder(CalendarReminder(eventID: "call", title: "call", minutes: 5, color: first.color))
        #expect(store.model.surface == .alert(shown))
        #expect(store.model.alertQueue.count == 1)

        clock.dismiss("later", now: Self.at(-300))
        #expect(store.model.alertQueue.isEmpty)
        #expect(store.model.surface == .alert(shown))
    }
}
