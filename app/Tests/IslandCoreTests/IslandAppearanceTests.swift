import Testing

@testable import IslandCore

struct IslandAppearanceTests {
  @Test("Hide media title extras чистит только показанный текст: info.title и trackKey не трогает")
  func titleForInfoKeepsTrackKey() {
    var appearance = IslandAppearance.default
    let info = NowPlayingInfo(title: "Song (Official Video)", artist: "Artist", isPlaying: true)

    // выключено (значение по умолчанию) — показываем название как есть
    #expect(appearance.title(for: info) == "Song (Official Video)")

    appearance.hidesTitleExtras = true
    #expect(appearance.title(for: info) == "Song")
    // регрессия: раньше IslandView подменял info.title, из-за чего у ArtworkFlip менялся trackKey
    // и обложка лишний раз переворачивалась при каждом переключении настройки
    #expect(info.title == "Song (Official Video)")
    #expect(info.trackKey == "Song (Official Video)|Artist|")
  }

  @Test("Без трека показывать нечего")
  func titleForNilInfo() {
    #expect(IslandAppearance.default.title(for: nil) == nil)
  }
}
