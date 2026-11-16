import Foundation
import Testing

@testable import Oasis

@Suite(.serialized)
@MainActor
struct LimitsSettingsTests {
  @Test("Настройки Codex переживают перезапуск и не меняют Claude")
  func independentPersistence() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    defaults.set(false, forKey: "codex.limits.enabled")
    let codex = LimitsSettings(defaults: defaults, namespace: "codex.limits")
    let claude = LimitsSettings(defaults: defaults)
    #expect(!codex.enabled)
    #expect(claude.enabled)
    codex.thresholds = [10, 5]
    codex.criticalSound = false
    codex.resetNotice = true
    codex.expandedView = false
    codex.forecastUntilWorkday = true
    codex.workdayEnd = 1080
    let restored = LimitsSettings(defaults: defaults, namespace: "codex.limits")
    #expect(restored.thresholds == [10, 5])
    #expect(!restored.criticalSound && restored.resetNotice && !restored.expandedView)
    #expect(restored.horizon == .workdayEnd(minutes: 1080))
    #expect(claude.thresholds == [50, 25, 10, 5])
    #expect(claude.expandedView && claude.criticalSound && !claude.resetNotice)
  }

  @Test("Изменения настроек применяются один раз, время ограничено допустимым диапазоном")
  func changesAndBounds() {
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let settings = LimitsSettings(defaults: defaults, namespace: "codex.limits")
    var changes = 0
    settings.onChange = { changes += 1 }
    settings.sessionWarning = false
    settings.sessionWarning = false
    #expect(changes == 1)
    settings.forecastUntilWorkday = true
    settings.workdayEnd = 9999
    #expect(settings.horizon == .workdayEnd(minutes: 1380))
    settings.thresholds = [5, 42, -1]
    #expect(settings.alertConfig.thresholds == [5])
  }
}
