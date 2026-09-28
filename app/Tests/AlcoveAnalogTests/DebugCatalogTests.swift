import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

// Тесты действий, которые внутри вызывают DebugScript.run (серии, сценарии, demo.run), сюда не кладём:
// у DebugScript.current общий на процесс слот, для них место в сериализованной суите DebugScriptTests
@MainActor
struct DebugCatalogTests {
    static func actions(_ store: IslandStore) -> [DebugAction] {
        DebugCatalog.sections(store: store).flatMap(\.actions)
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

    @Test("Debug-переключатель Expand on Hover отражает и меняет конфиг машины")
    func expandOnHoverToggle() throws {
        let store = IslandStore(config: .user)
        #expect(store.config.expandsOnHover)
        let toggle = try #require(Self.actions(store).first { $0.id == "settings.expand-on-hover" })
        #expect(toggle.isOn?() == true)
        toggle.run()
        #expect(!store.config.expandsOnHover)
        #expect(toggle.isOn?() == false)
        toggle.run()
        #expect(store.config.expandsOnHover)
        #expect(toggle.isOn?() == true)
    }
}
