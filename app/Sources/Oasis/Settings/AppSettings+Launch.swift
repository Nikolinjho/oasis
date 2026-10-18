import Foundation

extension AppSettings {
  /// Миграция старого домена выполняется до первого чтения настроек.
  static func afterLegacyMigration() -> AppSettings {
    LegacyDefaultsMigration.runAtLaunch()
    return AppSettings()
  }
}
