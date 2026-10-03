import Foundation

/// Отдельный домен UserDefaults на тест. Имя домена — абсолютный путь во временной папке: cfprefsd пишет plist
/// туда, а не в ~/Library/Preferences. removePersistentDomain оставляет пустой plist, а cfprefsd пересоздаёт его
/// асинхронно уже после удаления файла, поэтому домены в Preferences копились тысячами
enum TestDefaults {
  static let directory = FileManager.default.temporaryDirectory.appendingPathComponent("oasis-tests")

  static func fresh() -> (name: String, defaults: UserDefaults) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = directory.appendingPathComponent("defaults-\(UUID().uuidString)").path
    return (name, UserDefaults(suiteName: name)!)
  }

  /// Где оказался бы plist домена, если бы cfprefsd положил его в Preferences
  static func preferencesURL(_ name: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Preferences/\((name as NSString).lastPathComponent).plist")
  }

  /// synchronize принудительно проталкивает запись перед удалением: без неё под параллельной
  /// нагрузкой swift test отложенный флаш cfprefsd иногда обгоняет removePersistentDomain
  static func cleanup(_ name: String, _ defaults: UserDefaults) {
    defaults.synchronize()
    defaults.removePersistentDomain(forName: name)
    defaults.synchronize()
    try? FileManager.default.removeItem(atPath: name + ".plist")
  }
}
