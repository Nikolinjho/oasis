import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

@MainActor
struct IslandStoreTests {
    static func event(_ id: String, now: Date) -> CalendarEvent {
        CalendarEvent(
            id: id, title: id, start: now.addingTimeInterval(60), end: now.addingTimeInterval(120),
            isAllDay: false, color: RGB(red: 1, green: 0, blue: 0))
    }

    @Test("Отладочная повестка держится, пока живой источник шлёт apply(events:), и снимается unpinDebugEvents")
    func pinKeepsFakeAgendaUntilUnpinned() {
        let store = IslandStore()
        let now = Date()
        let real = [Self.event("real", now: now)]
        let fake = [Self.event("fake", now: now)]

        // живой источник уже что-то прислал до отладки
        store.apply(events: real, now: now)
        #expect(store.agenda.today.map(\.id) == ["real"])

        // отладка закрепляет фейковую повестку
        store.pinDebugEvents(fake, now: now)
        #expect(store.isDebugAgendaPinned)
        #expect(store.agenda.today.map(\.id) == ["fake"])

        // очередной reload живого источника (таймер 5 минут, EKEventStoreChanged) не должен её стереть
        store.apply(events: real, now: now)
        #expect(store.agenda.today.map(\.id) == ["fake"], "живой источник не должен перетирать закреплённую повестку")

        // возврат к реальному календарю восстанавливает последние реальные события
        store.unpinDebugEvents(now: now)
        #expect(!store.isDebugAgendaPinned)
        #expect(store.agenda.today.map(\.id) == ["real"])
    }

    @Test("Duo Empty Day закрепляет пустой день и переживает apply(events:) с реальными событиями")
    func pinEmptyDaySurvivesRealReload() {
        let store = IslandStore()
        let now = Date()
        store.apply(events: [Self.event("real", now: now)], now: now)

        store.pinDebugEvents([], now: now)
        #expect(store.agenda == .empty)

        store.apply(events: [Self.event("real", now: now)], now: now)
        #expect(store.agenda == .empty, "пустая отладочная повестка тоже не должна перетираться")

        store.unpinDebugEvents(now: now)
        #expect(store.agenda.today.map(\.id) == ["real"])
    }
}
