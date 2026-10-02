import Foundation
import Testing

@testable import Oasis

// .serialized и уборка домена — по той же причине, что в AppSettingsTests: суит пишется на диск через cfprefsd
@Suite(.serialized)
struct LegacyDefaultsMigrationTests {
  static func freshDefaults() -> (name: String, defaults: UserDefaults) {
    let name = "oasis-tests-\(UUID().uuidString)"
    return (name, UserDefaults(suiteName: name)!)
  }

  static func cleanup(_ name: String, _ defaults: UserDefaults) {
    defaults.synchronize()
    defaults.removePersistentDomain(forName: name)
    defaults.synchronize()
  }

  @Test("Ключи старого домена Alcove Analog копируются в новые настройки и ставится метка")
  func copiesLegacyKeys() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let legacy: [String: Any] = ["expandOnHover": false, "hoverDuration": 0.4, "display": "builtIn"]
    LegacyDefaultsMigration.run(legacy: legacy, into: defaults)
    #expect(defaults.object(forKey: "expandOnHover") as? Bool == false)
    #expect(defaults.double(forKey: "hoverDuration") == 0.4)
    #expect(defaults.string(forKey: "display") == "builtIn")
    #expect(defaults.bool(forKey: LegacyDefaultsMigration.markerKey))
  }

  @Test("Уже заданные в новом домене ключи не перезаписываются")
  func keepsExistingKeys() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    defaults.set(true, forKey: "expandOnHover")
    LegacyDefaultsMigration.run(legacy: ["expandOnHover": false, "playSounds": false], into: defaults)
    #expect(defaults.bool(forKey: "expandOnHover"))
    #expect(defaults.object(forKey: "playSounds") as? Bool == false)
  }

  @Test("Миграция срабатывает один раз: повторный запуск ничего не копирует")
  func runsOnlyOnce() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    LegacyDefaultsMigration.run(legacy: ["hoverDuration": 0.4], into: defaults)
    defaults.removeObject(forKey: "hoverDuration")
    LegacyDefaultsMigration.run(legacy: ["hoverDuration": 0.4, "playSounds": false], into: defaults)
    #expect(defaults.object(forKey: "hoverDuration") == nil)
    #expect(defaults.object(forKey: "playSounds") == nil)
  }

  @Test("Без старого домена миграция ничего не пишет, даже метку")
  func noLegacyDomainIsNoOp() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    LegacyDefaultsMigration.run(legacy: nil, into: defaults)
    #expect(defaults.persistentDomain(forName: name)?.isEmpty ?? true)
    #expect(defaults.object(forKey: LegacyDefaultsMigration.markerKey) == nil)
  }
}
