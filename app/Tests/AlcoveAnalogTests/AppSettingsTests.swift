import CoreGraphics
import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

// .serialized: тесты пишут в UserDefaults(suiteName:) на диск через cfprefsd. Параллельно с другими
// тестами того же файла это иногда обгоняет removePersistentDomain (запись после удаления) и
// оставляет в ~/Library/Preferences файл с настоящими значениями, а не пустым доменом
@Suite(.serialized)
@MainActor
struct AppSettingsTests {
    /// Каждый суит уникален (UUID), но домен реально пишется в ~/Library/Preferences: без удаления
    /// он там и остаётся. Возвращаем имя вместе с defaults, чтобы тест мог убрать его за собой
    static func freshDefaults() -> (name: String, defaults: UserDefaults) {
        let name = "alcove-analog-tests-\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    /// synchronize принудительно проталкивает запись перед удалением: без неё под параллельной
    /// нагрузкой swift test отложенный флаш cfprefsd иногда обгоняет removePersistentDomain
    static func cleanup(_ name: String, _ defaults: UserDefaults) {
        defaults.synchronize()
        defaults.removePersistentDomain(forName: name)
        defaults.synchronize()
    }

    @Test("По умолчанию как в Alcove: Expand on hover вкл, 0 с, главный экран, без виртуального выреза")
    func defaultsMatchAlcove() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.expandOnHover)
        #expect(settings.hoverDuration == 0)
        #expect(settings.display == .main)
        #expect(!settings.forceSimulatedNotch)
        #expect(settings.builtInNotch == nil)
        #expect(settings.playSounds)
    }

    @Test("Настройки переживают перезапуск, каждое изменение зовёт onChange")
    func persists() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        var calls = 0
        settings.onChange = { calls += 1 }
        settings.expandOnHover = false
        settings.hoverDuration = 0.3
        settings.forceSimulatedNotch = true
        settings.display = .named("DELL U2723QE")
        settings.builtInNotch = CGSize(width: 186, height: 32)
        settings.playSounds = false

        let again = AppSettings(defaults: defaults)
        #expect(!again.expandOnHover)
        #expect(again.hoverDuration == 0.3)
        #expect(again.forceSimulatedNotch)
        #expect(again.display == .named("DELL U2723QE"))
        #expect(again.builtInNotch == CGSize(width: 186, height: 32))
        #expect(!again.playSounds)
        // запомненный вырез — служебное значение, настройки он не меняет
        #expect(calls == 5)
    }

    @Test("Повторная запись того же значения onChange не зовёт")
    func noChangeNoCall() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        settings.expandOnHover = false
        settings.hoverDuration = 0.3
        settings.forceSimulatedNotch = true
        settings.display = .named("DELL U2723QE")
        var calls = 0
        settings.onChange = { calls += 1 }
        settings.expandOnHover = false
        settings.hoverDuration = 0.3
        settings.forceSimulatedNotch = true
        settings.display = .named("DELL U2723QE")
        #expect(calls == 0)
    }

    @Test("Сброс виртуального выреза убирает обе записи из UserDefaults")
    func clearingBuiltInNotchRemovesKeys() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        settings.builtInNotch = CGSize(width: 186, height: 32)
        settings.builtInNotch = nil
        #expect(settings.builtInNotch == nil)
        #expect(defaults.object(forKey: AppSettings.Key.builtInNotchWidth) == nil)
        #expect(defaults.object(forKey: AppSettings.Key.builtInNotchHeight) == nil)
    }

    @Test("Hide menu bar icon: по умолчанию выкл, переживает перезапуск, зовёт onChange")
    func hideMenuBarIcon() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.hideMenuBarIcon)
        var calls = 0
        settings.onChange = { calls += 1 }
        settings.hideMenuBarIcon = true
        #expect(calls == 1)
        #expect(AppSettings(defaults: defaults).hideMenuBarIcon)
    }

    @Test("Подгонка выреза: по умолчанию 0, зажата в −2…2, переживает перезапуск")
    func notchTuning() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.notchTuning == NotchTuning())
        settings.notchWidthOffset = -2
        settings.notchHeightOffset = 5
        #expect(settings.notchTuning == NotchTuning(width: -2, height: 2))
        let again = AppSettings(defaults: defaults)
        #expect(again.notchWidthOffset == -2)
    }

    @Test("Hover-настройки попадают в конфиг машины, темп остаётся от базы")
    func machineConfig() {
        let (name, defaults) = Self.freshDefaults()
        defer { Self.cleanup(name, defaults) }
        let settings = AppSettings(defaults: defaults)
        settings.expandOnHover = false
        settings.hoverDuration = 0.2
        let config = settings.machineConfig(from: .user)
        #expect(!config.expandsOnHover)
        #expect(config.hoverDelay == .milliseconds(200))
        #expect(config.timeScale == IslandMachine.Config.user.timeScale)
    }
}
