/// Браузеры: MediaRemote у них без переключения треков и без доп. кнопки плеера (Alcove 1.7.9, Chrome с YouTube, 28.09).
/// Нужен, пока адаптер не отдаёт prohibitsSkip: у Chrome ключа нет (итоги Task 0)
enum BrowserSources {
  static let bundleIDs: Set<String> = [
    "com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "company.thebrowser.Browser",
    "com.microsoft.edgemac", "ru.yandex.desktop.yandex-browser", "com.brave.Browser",
    "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
  ]

  static func contains(_ bundleID: String?) -> Bool {
    bundleID.map(bundleIDs.contains) ?? false
  }
}
