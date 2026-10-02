import Testing

@testable import IslandSources

struct AdapterSeekTests {
  @Test("Аргументы seek: секунды в микросекунды, отрицательная позиция зажата в 0")
  func seekArguments() {
    #expect(AdapterNowPlayingSource.seekArguments(42) == ["seek", "42000000"])
    #expect(AdapterNowPlayingSource.seekArguments(-1) == ["seek", "0"])
    #expect(AdapterNowPlayingSource.seekArguments(1.2345678) == ["seek", "1234568"])
  }
}
