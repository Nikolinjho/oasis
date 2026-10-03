import Foundation
import IslandCore
import IslandSources
import Testing

@testable import Oasis

/// Источник без адаптера: события шлёт тест, start/stop считаются
final class FakeNowPlayingSource: NowPlayingSource, @unchecked Sendable {
  let changes: AsyncStream<NowPlayingChange>
  let continuation: AsyncStream<NowPlayingChange>.Continuation
  private(set) var starts = 0
  private(set) var stops = 0

  init() { (changes, continuation) = AsyncStream.makeStream() }

  func start() { starts += 1 }
  func stop() { stops += 1 }
  func send(_ command: MediaCommand) {}
  func setShuffle(_ mode: Int) {}
  func setRepeat(_ mode: Int) {}
  func seek(to position: TimeInterval) {}
}

@MainActor
struct NowPlayingSourceSwitcherTests {
  static let old = NowPlayingChange.newTrack(NowPlayingInfo(title: "Old", isPlaying: true))
  static let new = NowPlayingChange.newTrack(NowPlayingInfo(title: "New", isPlaying: true))

  /// Свитчер с фейками на каждый выбор: события копятся в received
  @MainActor
  final class Harness {
    var made: [MediaSourceChoice: FakeNowPlayingSource] = [:]
    var received: [NowPlayingChange] = []
    lazy var switcher = NowPlayingSourceSwitcher(
      make: { [unowned self] choice in
        let source = FakeNowPlayingSource()
        made[choice] = source
        return source
      },
      onChange: { [unowned self] change in received.append(change) })

    /// Ждёт, пока задачи потоков доставят count событий
    func waitFor(_ count: Int) async {
      for _ in 0..<1000 where received.count < count { await Task.yield() }
    }
  }

  @Test("Первый выбор запускает источник и не шлёт cleared: чистить ещё нечего")
  func firstApplyStarts() async {
    let harness = Harness()
    harness.switcher.apply(.system)
    #expect(harness.made[.system]?.starts == 1)
    harness.made[.system]?.continuation.yield(Self.old)
    await harness.waitFor(1)
    #expect(harness.received == [Self.old])
  }

  @Test("Тот же выбор повторно (applySettings на любую настройку) источник не перезапускает")
  func sameChoiceKeepsSource() {
    let harness = Harness()
    harness.switcher.apply(.system)
    let first = harness.made[.system]
    harness.switcher.apply(.system)
    #expect(harness.made[.system] === first)
    #expect(first?.starts == 1)
    #expect(first?.stops == 0)
  }

  @Test("Смена выбора гасит старый источник, чистит трек и запускает новый; события старого больше не доходят")
  func switchClearsAndRestarts() async {
    let harness = Harness()
    harness.switcher.apply(.system)
    let old = harness.made[.system]
    old?.continuation.yield(Self.old)
    await harness.waitFor(1)

    harness.switcher.apply(.yandexMusic)
    #expect(old?.stops == 1)
    #expect(harness.made[.yandexMusic]?.starts == 1)
    #expect(harness.received == [Self.old, .cleared])

    old?.continuation.yield(Self.old)
    harness.made[.yandexMusic]?.continuation.yield(Self.new)
    await harness.waitFor(3)
    #expect(harness.received == [Self.old, .cleared, Self.new])
  }

  @Test("Источник не создался (нет адаптера): старый всё равно погашен и трек очищен")
  func switchToMissingSource() {
    var available = true
    let old = FakeNowPlayingSource()
    var received: [NowPlayingChange] = []
    let switcher = NowPlayingSourceSwitcher(
      make: { _ in available ? old : nil }, onChange: { received.append($0) })
    switcher.apply(.system)
    available = false
    switcher.apply(.yandexMusic)
    #expect(old.stops == 1)
    #expect(received == [.cleared])
    #expect(switcher.source == nil)
  }

  @Test("stop гасит текущий источник")
  func stopStopsCurrent() {
    let harness = Harness()
    harness.switcher.apply(.system)
    harness.switcher.stop()
    #expect(harness.made[.system]?.stops == 1)
  }
}
