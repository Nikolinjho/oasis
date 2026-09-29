import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

// Тесты действий, которые внутри вызывают DebugScript.run (серии, сценарии, demo.run), сюда не кладём:
// у DebugScript.current общий на процесс слот, для них место в сериализованной суите DebugScriptTests
@MainActor
struct DebugCatalogTests {
    static func actions(_ store: IslandStore, _ settings: AppSettings? = nil) -> [DebugAction] {
        DebugCatalog.sections(store: store, settings: settings).flatMap(\.actions)
    }

    @Test("id отладочных действий уникальны и годятся для ссылки")
    func idsAreUniqueAndURLSafe() {
        let ids = Self.actions(IslandStore()).map(\.id)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "." || $0 == "-" }, "\(id)")
        }
    }

    @Test("Ссылка alcove-analog://debug/<id> даёт id действия, другие ссылки — nil")
    func parsesURL() {
        #expect(DebugURL.actionID(from: URL(string: "alcove-analog://debug/hud.sound.50")!) == "hud.sound.50")
        #expect(DebugURL.actionID(from: URL(string: "alcove-analog://debug/")!) == nil)
        #expect(DebugURL.actionID(from: URL(string: "alcove-analog://settings/general")!) == nil)
        #expect(DebugURL.actionID(from: URL(string: "https://debug/hud.sound.50")!) == nil)
        // регистр схемы и хоста не важен, хвостовой слэш и query не мешают разбору
        #expect(DebugURL.actionID(from: URL(string: "ALCOVE-ANALOG://DEBUG/hud.sound.50")!) == "hud.sound.50")
        #expect(DebugURL.actionID(from: URL(string: "alcove-analog://debug/hud.sound.50/")!) == "hud.sound.50")
        #expect(DebugURL.actionID(from: URL(string: "alcove-analog://debug/hud.sound.50?x=1")!) == "hud.sound.50")
    }

    @Test("Sound 50% ставит остров в HUD громкости с уровнем 0.5")
    func hudActionReachesMachine() throws {
        let store = IslandStore(config: .alcove)
        let action = try #require(Self.actions(store).first { $0.id == "hud.sound.50" })
        action.run()
        #expect(store.model.surface == .hud(.volume, level: 0.5))
    }

    @Test("Peek Now без трека ничего не делает, с треком повторяет peek из компакта")
    func peekActionNeedsTrack() throws {
        let store = IslandStore(config: .alcove)
        let peek = try #require(Self.actions(store).first { $0.id == "music.peek" })
        peek.run()
        #expect(store.model.surface == .idle)
        #expect(store.nowPlaying == nil)

        let next = try #require(Self.actions(store).first { $0.id == "music.next" })
        next.run()
        #expect(store.model.surface == .compact)

        peek.run()
        #expect(store.model.surface == .peek)
        #expect(store.nowPlaying != nil)
    }

    @Test("Переключатели таймингов меняют timeScale и отмечают текущий")
    func timingModes() throws {
        let store = IslandStore(config: .user)
        let actions = Self.actions(store)
        let slow = try #require(actions.first { $0.id == "timing.slow" })
        let user = try #require(actions.first { $0.id == "timing.user" })
        slow.run()
        #expect(store.config.timeScale == 5)
        #expect(slow.isOn?() == true)
        #expect(user.isOn?() == false)
    }

    @Test("Duo With Fake Event и Duo Empty Day закрепляют повестку, Use Real Calendar её снимает")
    func calendarActionsPinAndUnpin() throws {
        let store = IslandStore()
        let actions = Self.actions(store)
        let duoEvent = try #require(actions.first { $0.id == "calendar.duo-event" })
        let duoEmpty = try #require(actions.first { $0.id == "calendar.duo-empty" })
        let real = try #require(actions.first { $0.id == "calendar.real" })

        duoEvent.run()
        #expect(store.isDebugAgendaPinned)
        #expect(store.agenda.today.map(\.title) == ["Fake Event"])
        #expect(store.model.surface == .expanded)

        duoEmpty.run()
        #expect(store.isDebugAgendaPinned)
        #expect(store.agenda == .empty)

        real.run()
        #expect(!store.isDebugAgendaPinned)
    }

    @Test("Duo With Fake Event открывает Duo даже при другой Idle Activity (Task 14)")
    func calendarActionsAlwaysOpenDuo() throws {
        let store = IslandStore()
        store.config.expanded.idleActivity = .none
        let duoEvent = try #require(Self.actions(store).first { $0.id == "calendar.duo-event" })
        duoEvent.run()
        #expect(store.model.surface == .expanded && store.model.expandedView == .duo)
        // настройка не осталась переключённой отладочным действием
        #expect(store.config.expanded.idleActivity == .none)
    }

    @Test("Cycle Idle Activity идёт по кругу None → Playing → Calendar → Duo → None")
    func cycleIdleActivityAction() throws {
        let store = IslandStore()
        store.config.expanded.idleActivity = .none
        let cycle = try #require(Self.actions(store).first { $0.id == "island.cycle-idle-activity" })
        var seen: [IdleActivity] = []
        for _ in 0..<4 {
            cycle.run()
            seen.append(store.config.expanded.idleActivity)
        }
        #expect(seen == [.playing, .calendar, .duo, .none])
    }

    @Test("Debug-переключатель Expand on Hover идёт через AppSettings, а не мимо него в store.config")
    func expandOnHoverToggle() throws {
        let (name, defaults) = AppSettingsTests.freshDefaults()
        defer { AppSettingsTests.cleanup(name, defaults) }
        let store = IslandStore(config: .user)
        let settings = AppSettings(defaults: defaults)
        // как в AppDelegate.applySettings: изменение настройки долетает до машины через onChange
        settings.onChange = { store.config = settings.machineConfig(from: store.config) }

        #expect(settings.expandOnHover)
        let toggle = try #require(Self.actions(store, settings).first { $0.id == "settings.expand-on-hover" })
        #expect(toggle.isOn?() == true)

        toggle.run()
        #expect(!settings.expandOnHover)
        #expect(!store.config.expandsOnHover)
        #expect(toggle.isOn?() == false)

        toggle.run()
        #expect(settings.expandOnHover)
        #expect(store.config.expandsOnHover)
        #expect(toggle.isOn?() == true)
    }

    @Test("Без settings (запасной путь) переключатель по-прежнему меняет store.config напрямую")
    func expandOnHoverToggleFallsBackWithoutSettings() throws {
        let store = IslandStore(config: .user)
        #expect(store.config.expandsOnHover)
        let toggle = try #require(Self.actions(store).first { $0.id == "settings.expand-on-hover" })
        #expect(toggle.isOn?() == true)
        toggle.run()
        #expect(!store.config.expandsOnHover)
        #expect(toggle.isOn?() == false)
    }

    @Test("DebugCalendarLive закрывает окно календаря сама по истечении event.end (задача 3)")
    func debugCalendarLiveClosesAtEnd() async throws {
        let store = IslandStore()
        let live = DebugCalendarLive()
        let now = Date()
        // короткое фейковое событие: конец через 0.05 с, чтобы тест не ждал реальные минуты
        let event = CalendarEvent(
            id: "fake-live", title: "Fake Event", start: now, end: now.addingTimeInterval(0.05),
            isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35))
        live.set(event, on: store, now: now)
        #expect(store.model.calendarLive)

        try await Task.sleep(for: .milliseconds(200))
        #expect(!store.model.calendarLive, "окно должно закрыться само по концу события")
    }

    @Test("DebugCalendarLive: новое debug-live-событие отменяет закрытие предыдущего")
    func debugCalendarLiveReplacementCancelsOldClose() async throws {
        let store = IslandStore()
        let live = DebugCalendarLive()
        let now = Date()
        // первое событие заканчивается почти сразу, но второе (длиннее) должно пережить его старый таймер
        let short = CalendarEvent(
            id: "fake-short", title: "Short", start: now, end: now.addingTimeInterval(0.05),
            isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35))
        let long = CalendarEvent(
            id: "fake-long", title: "Long", start: now, end: now.addingTimeInterval(5),
            isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35))
        live.set(short, on: store, now: now)
        live.set(long, on: store, now: now)

        try await Task.sleep(for: .milliseconds(200))
        #expect(store.model.calendarLive, "старый таймер short не должен закрыть уже подменённое событие long")
    }

    @Test("DebugCalendarLive.cancel останавливает запланированное закрытие")
    func debugCalendarLiveCancelStopsClose() async throws {
        let store = IslandStore()
        let live = DebugCalendarLive()
        let now = Date()
        let event = CalendarEvent(
            id: "fake-live", title: "Fake Event", start: now, end: now.addingTimeInterval(0.05),
            isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35))
        live.set(event, on: store, now: now)
        live.cancel()
        store.setCalendarLive(nil)

        try await Task.sleep(for: .milliseconds(200))
        #expect(!store.model.calendarLive)
    }

    @Test("airpods.connected и airpods.low показывают уведомление AirPods с полным и почти пустым кольцом")
    func airpodsActions() throws {
        for (id, battery) in [("airpods.connected", 1.0), ("airpods.low", 0.15)] {
            let store = IslandStore(config: .alcove)
            let action = try #require(Self.actions(store).first { $0.id == id })
            action.run()
            guard case let .alert(.airpods(info)) = store.model.surface else {
                Issue.record("\(id): \(store.model.surface)")
                continue
            }
            #expect(info.battery == battery)
        }
    }
}
