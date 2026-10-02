import Foundation

/// Перенос настроек после переименования Alcove Analog → Oasis: новый bundle id — новый домен UserDefaults.
/// Один раз при запуске, до чтения AppSettings, ключи старого домена копируются туда, где в новом их ещё нет.
/// Старый домен не удаляется: к нему можно вернуться, если что-то перенеслось не так
enum LegacyDefaultsMigration {
  /// Домен прежнего bundle id
  static let legacyDomain = "dev.nikoko.alcove-analog"
  /// Метка в новом домене: миграция уже прошла, повторно не копируем
  static let markerKey = "migratedFromAlcoveAnalog"

  /// legacy — содержимое старого домена, nil — домена нет (свежая установка): тогда ничего не пишем
  static func run(legacy: [String: Any]?, into defaults: UserDefaults) {
    guard let legacy, !defaults.bool(forKey: markerKey) else { return }
    for (key, value) in legacy where defaults.object(forKey: key) == nil {
      defaults.set(value, forKey: key)
    }
    defaults.set(true, forKey: markerKey)
  }

  /// Запуск приложения: старый домен читается из .standard по имени
  static func runAtLaunch(defaults: UserDefaults = .standard) {
    run(legacy: defaults.persistentDomain(forName: legacyDomain), into: defaults)
  }
}
