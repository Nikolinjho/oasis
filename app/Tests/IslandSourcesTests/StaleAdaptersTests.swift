import Testing

@testable import IslandSources

struct StaleAdaptersTests {
  /// Вывод `ps -axo pid=,ppid=,command=`: pid выровнены пробелами слева
  static let ps = """
      101     1 /usr/bin/perl /Users/me/alcove-wt/task-6/app/build/Oasis.app/Contents/Resources/mediaremote-adapter.pl /Users/me/alcove-wt/task-6/app/build/Oasis.app/Contents/Resources/MediaRemoteAdapter.framework stream --no-diff
      102   900 /usr/bin/perl /Users/me/oasis/app/build/Oasis.app/Contents/Resources/mediaremote-adapter.pl /x stream
      103     1 /usr/bin/perl /opt/other/mediaremote-adapter.pl /x stream
      104     1 /Applications/Alcove.app/Contents/MacOS/Alcove
      900     1 /Users/me/oasis/app/build/Oasis.app/Contents/MacOS/Oasis
    """

  @Test("Сирота — адаптер из нашей сборки, которого усыновил launchd")
  func orphansOnly() {
    #expect(StaleAdapters.pids(psOutput: Self.ps) == [101])
  }

  @Test("Пустой вывод ps — сирот нет")
  func emptyOutput() {
    #expect(StaleAdapters.pids(psOutput: "").isEmpty)
  }

  @Test("Путь сборки с пробелом всё равно находится")
  func pathWithSpace() {
    let ps = """
        201     1 /usr/bin/perl /Users/me/My Builds/Oasis.app/Contents/Resources/mediaremote-adapter.pl /x stream
      """
    #expect(StaleAdapters.pids(psOutput: ps) == [201])
  }

  @Test("Строка заголовка ps без числовых pid/ppid игнорируется")
  func headerLineIgnored() {
    let ps = "  PID  PPID COMMAND"
    #expect(StaleAdapters.pids(psOutput: ps).isEmpty)
  }
}
