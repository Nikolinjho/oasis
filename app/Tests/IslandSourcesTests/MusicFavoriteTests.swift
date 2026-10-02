import Testing

@testable import IslandSources

struct MusicFavoriteTests {
  @Test("Нулевой код osascript — трек в избранном")
  func done() {
    #expect(MusicFavorite.outcome(status: 0, stderr: "") == .done)
  }

  @Test("-1743: пользователь не дал управлять Music")
  func notAuthorized() {
    let stderr = "0:69: execution error: Not authorized to send Apple events to Music. (-1743)\n"
    #expect(MusicFavorite.outcome(status: 1, stderr: stderr) == .notAuthorized)
  }

  @Test("Остальные ошибки отдаются текстом без переводов строки")
  func failed() {
    let stderr = "0:60: execution error: Music got an error: Can’t get current track. (-1728)\n"
    #expect(
      MusicFavorite.outcome(status: 1, stderr: stderr)
        == .failed("0:60: execution error: Music got an error: Can’t get current track. (-1728)"))
  }

  @Test("Скрипт ставит favorited текущему треку по bundle id, а не по имени")
  func script() {
    #expect(MusicFavorite.script.contains("application id \"com.apple.Music\""))
    #expect(MusicFavorite.script.contains("set favorited of current track to true"))
  }
}
