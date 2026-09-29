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

    @Test("onAgendaChange получает повестку после apply, pin и unpin, закреплённая apply молчит")
    func agendaChangeFeedsClock() {
        let store = IslandStore()
        let now = Date()
        var seen: [[String]] = []
        store.onAgendaChange = { seen.append($0.today.map(\.id)) }
        store.apply(events: [Self.event("real", now: now)], now: now)
        store.pinDebugEvents([Self.event("fake", now: now)], now: now)
        store.apply(events: [Self.event("real2", now: now)], now: now)
        store.unpinDebugEvents(now: now)
        #expect(seen == [["real"], ["fake"], ["real2"]])
    }

    @Test("Spec компакта календаря при играющей музыке — размеры компакта музыки, без музыки — прежний пол")
    func calendarSpecFollowsMusic() {
        let store = IslandStore(config: .alcove)
        store.send(.trackChanged)
        store.send(.calendarLiveChanged(true))
        store.send(.timerFired(.grow))
        #expect(store.model.surface == .calendar)
        #expect(store.model.showsMedia)
        // компакт музыки notch-relative (задача 1): на store.notch по умолчанию (185) 257+2 = 259
        #expect(store.spec.size == CGSize(width: 259, height: 32))

        store.send(.mediaCleared)
        #expect(store.model.surface == .calendar)
        #expect(!store.model.showsMedia)
        // без музыки — тело календаря (254, замер 1.7.7), тоже notch-relative: 254+2 = 256;
        // пол по «60s» на этом notch его не превышает
        #expect(store.spec.size == CGSize(width: 256, height: 32))
    }

    @Test("apply(.updated) без текущего трека ведёт себя как новый трек: компакт возвращается")
    func updatedWithoutCurrentTrackActsLikeNewTrack() {
        let store = IslandStore()
        store.apply(.newTrack(NowPlayingInfo(title: "T", isPlaying: true)))
        #expect(store.model.surface == .compact)

        // отладочный music.clear очищает store, но парсер адаптера этого не знает и продолжает
        // слать .updated по тому же треку (репродукция живой проверки)
        store.apply(.cleared)
        #expect(store.model.surface == .idle)
        #expect(!store.model.hasMedia)

        store.apply(.updated(NowPlayingInfo(title: "T", isPlaying: true)))
        #expect(store.nowPlaying?.title == "T")
        #expect(store.model.hasMedia)
        #expect(store.model.surface == .compact)
    }

    @Test("apply(.updated) без текущего трека на паузе — как pausedTrackChanged, а не молчаливое обновление")
    func updatedWithoutCurrentTrackRespectsPause() {
        let store = IslandStore()
        store.apply(.updated(NowPlayingInfo(title: "T", isPlaying: false)))
        #expect(store.nowPlaying?.title == "T")
        #expect(store.model.hasMedia)
        #expect(!store.model.isPlaying)
    }

    @Test("apply(.updated) с текущим треком по-прежнему просто обновляет данные, не переигрывая newTrack")
    func updatedWithCurrentTrackStaysUpdate() {
        let store = IslandStore()
        store.apply(.newTrack(NowPlayingInfo(title: "T", isPlaying: true)))
        #expect(store.model.surface == .compact)

        store.apply(.updated(NowPlayingInfo(title: "T2", isPlaying: true)))
        #expect(store.nowPlaying?.title == "T2")
        // тот же трек продолжает играть: surface не переигрывает вход заново
        #expect(store.model.surface == .compact)
    }
}
