import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

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
    }

    @Test("Sound 50% ставит остров в HUD громкости с уровнем 0.5")
    func hudActionReachesMachine() throws {
        let store = IslandStore(config: .alcove)
        let action = try #require(Self.actions(store).first { $0.id == "hud.sound.50" })
        action.run()
        #expect(store.model.surface == .hud(.volume, level: 0.5))
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
}
