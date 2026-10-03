import Testing

@testable import IslandCore

struct TitleCleanerTests {
  @Test("Hide media title extras: хвосты видео и лирики уходят, соавторы остаются")
  func clean() {
    #expect(TitleCleaner.clean("Song (Official Video)") == "Song")
    #expect(TitleCleaner.clean("Song [Official Music Video]") == "Song")
    #expect(TitleCleaner.clean("Song (Lyrics)") == "Song")
    #expect(TitleCleaner.clean("Song (Official Audio) [4K]") == "Song")
    #expect(TitleCleaner.clean("Song | Official Audio") == "Song")
    #expect(TitleCleaner.clean("Song (Remastered 2011)") == "Song")
    #expect(TitleCleaner.clean("Song (feat. Artist)") == "Song (feat. Artist)")
    #expect(TitleCleaner.clean("Song") == "Song")
  }

  @Test("Название целиком из хвоста не превращается в пустую строку")
  func keepsWholeTitle() {
    #expect(TitleCleaner.clean("(Official Video)") == "(Official Video)")
  }

  @Test("Скобки, где служебное слово лишь часть названия, остаются")
  func keepsBracketsWithOtherWords() {
    #expect(TitleCleaner.clean("Song (Live in HD Arena)") == "Song (Live in HD Arena)")
    #expect(TitleCleaner.clean("Song (Clip Art Remix)") == "Song (Clip Art Remix)")
    #expect(TitleCleaner.clean("Song (1999)") == "Song (1999)")
    #expect(TitleCleaner.clean("Song | Video Games Live") == "Song | Video Games Live")
  }

  @Test("Хвост через дефис или тире срезается, дефис внутри слова — нет")
  func dashTail() {
    #expect(TitleCleaner.clean("Artist - Song - Official Video") == "Artist - Song")
    #expect(TitleCleaner.clean("Song – Official Music Video") == "Song")
    #expect(TitleCleaner.clean("Song — Official Audio") == "Song")
    #expect(TitleCleaner.clean("Anti-Hero") == "Anti-Hero")
    #expect(TitleCleaner.clean("Artist - Song") == "Artist - Song")
  }

  @Test("Русские хвосты срезаются так же, как английские")
  func russianTails() {
    #expect(TitleCleaner.clean("Песня (Официальное видео)") == "Песня")
    #expect(TitleCleaner.clean("Песня (Премьера клипа)") == "Песня")
    #expect(TitleCleaner.clean("Песня (Клип)") == "Песня")
    #expect(TitleCleaner.clean("Песня [Official Video]") == "Песня")
    #expect(TitleCleaner.clean("Песня | Премьера клипа 2024") == "Песня")
    #expect(TitleCleaner.clean("Песня - Официальный клип") == "Песня")
  }
}

extension TitleCleanerTests {
  @Test("Модификаторы (Live, Animated, Version, in…) срезаются только вместе с настоящей меткой")
  func modifiersNextToTag() {
    #expect(TitleCleaner.clean("Song (Official Live Video)") == "Song")
    #expect(TitleCleaner.clean("Song (Official Animated Video)") == "Song")
    #expect(TitleCleaner.clean("Song (Official Performance Video)") == "Song")
    #expect(TitleCleaner.clean("Song (Remastered Version)") == "Song")
    #expect(TitleCleaner.clean("Song (Official Music Video - Explicit)") == "Song")
    #expect(TitleCleaner.clean("Song (Official Video 4K60)") == "Song")
    #expect(TitleCleaner.clean("Song (Official Music Video) [Remastered in 4K]") == "Song")
    #expect(TitleCleaner.clean("Song (Live)") == "Song (Live)")
    #expect(TitleCleaner.clean("Song (Live in HD Arena)") == "Song (Live in HD Arena)")
  }

  @Test("Одно голое служебное слово после дефиса — часть названия")
  func singleWordDashTail() {
    #expect(TitleCleaner.clean("India.Arie - Video") == "India.Arie - Video")
    #expect(TitleCleaner.clean("Artist – Clip") == "Artist – Clip")
  }

  @Test("Служебный сегмент между « | » срезается вместе со всем после него")
  func pipeSegment() {
    #expect(TitleCleaner.clean("Song | Official Video | Artist") == "Song")
    #expect(TitleCleaner.clean("Song | Artist | Official Audio") == "Song | Artist")
  }
}
