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
}
