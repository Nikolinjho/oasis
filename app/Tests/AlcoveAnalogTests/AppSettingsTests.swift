import CoreGraphics
import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

@MainActor
struct AppSettingsTests {
    static func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "alcove-analog-tests-\(UUID().uuidString)")!
    }

    @Test("По умолчанию как в Alcove: Expand on hover вкл, 0 с, главный экран, без виртуального выреза")
    func defaultsMatchAlcove() {
        let settings = AppSettings(defaults: Self.freshDefaults())
        #expect(settings.expandOnHover)
        #expect(settings.hoverDuration == 0)
        #expect(settings.display == .main)
        #expect(!settings.forceSimulatedNotch)
        #expect(settings.builtInNotch == nil)
    }

    @Test("Настройки переживают перезапуск, каждое изменение зовёт onChange")
    func persists() {
        let defaults = Self.freshDefaults()
        let settings = AppSettings(defaults: defaults)
        var calls = 0
        settings.onChange = { calls += 1 }
        settings.expandOnHover = false
        settings.hoverDuration = 0.3
        settings.forceSimulatedNotch = true
        settings.display = .named("DELL U2723QE")
        settings.builtInNotch = CGSize(width: 186, height: 32)

        let again = AppSettings(defaults: defaults)
        #expect(!again.expandOnHover)
        #expect(again.hoverDuration == 0.3)
        #expect(again.forceSimulatedNotch)
        #expect(again.display == .named("DELL U2723QE"))
        #expect(again.builtInNotch == CGSize(width: 186, height: 32))
        // запомненный вырез — служебное значение, настройки он не меняет
        #expect(calls == 4)
    }

    @Test("Hover-настройки попадают в конфиг машины, темп остаётся от базы")
    func machineConfig() {
        let settings = AppSettings(defaults: Self.freshDefaults())
        settings.expandOnHover = false
        settings.hoverDuration = 0.2
        let config = settings.machineConfig(from: .user)
        #expect(!config.expandsOnHover)
        #expect(config.hoverDelay == .milliseconds(200))
        #expect(config.timeScale == IslandMachine.Config.user.timeScale)
    }
}
