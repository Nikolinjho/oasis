import Foundation
import IslandCore
import Testing

@testable import IslandSources

/// Записывает, какой исполнитель и с чем вызван
@MainActor
final class FakePerformer: PlayerActionPerforming {
  enum Call: Equatable {
    case media(MediaCommand)
    case favorite
    case activate(String)
    case volume(Double)
    case stepVolume(up: Bool)
    case shuffle(Int)
    case repeatMode(Int)
    case seek(TimeInterval)
  }

  private(set) var calls: [Call] = []

  func send(_ command: MediaCommand) { calls.append(.media(command)) }
  func favoriteInMusic() { calls.append(.favorite) }
  func activateApp(bundleID: String) { calls.append(.activate(bundleID)) }
  func setVolume(_ level: Double) { calls.append(.volume(level)) }
  func stepVolume(up: Bool) { calls.append(.stepVolume(up: up)) }
  func setShuffle(_ mode: Int) { calls.append(.shuffle(mode)) }
  func setRepeat(_ mode: Int) { calls.append(.repeatMode(mode)) }
  func seek(to position: TimeInterval) { calls.append(.seek(position)) }
}

@MainActor
struct PlayerActionRouterTests {
  static func track(_ bundleID: String?) -> NowPlayingInfo {
    NowPlayingInfo(bundleID: bundleID, title: "Water", isPlaying: true)
  }

  @Test("Медиакоманда уходит в плеер как есть")
  func media() {
    let fake = FakePerformer()
    let router = PlayerActionRouter(performer: fake)
    router.perform(.media(.nextTrack), nowPlaying: Self.track("com.apple.Music"))
    router.perform(.media(.togglePlayPause), nowPlaying: nil)
    #expect(fake.calls == [.media(.nextTrack), .media(.togglePlayPause)])
  }

  @Test("Избранное — только когда играет Apple Music")
  func favoriteInMusic() {
    let fake = FakePerformer()
    PlayerActionRouter(performer: fake).perform(.favorite, nowPlaying: Self.track("com.apple.Music"))
    #expect(fake.calls == [.favorite])
  }

  @Test("Избранное у другого источника или без трека не трогает Music")
  func favoriteElsewhere() {
    let fake = FakePerformer()
    let router = PlayerActionRouter(performer: fake)
    router.perform(.favorite, nowPlaying: Self.track("com.spotify.client"))
    router.perform(.favorite, nowPlaying: Self.track(nil))
    router.perform(.favorite, nowPlaying: nil)
    #expect(fake.calls.isEmpty)
  }

  @Test("Открыть источник — приложение по bundleID текущего трека")
  func openSource() {
    let fake = FakePerformer()
    PlayerActionRouter(performer: fake).perform(.openSource, nowPlaying: Self.track("com.google.Chrome"))
    #expect(fake.calls == [.activate("com.google.Chrome")])
  }

  @Test("Без bundleID открывать нечего")
  func openSourceUnknown() {
    let fake = FakePerformer()
    let router = PlayerActionRouter(performer: fake)
    router.perform(.openSource, nowPlaying: Self.track(nil))
    router.perform(.openSource, nowPlaying: nil)
    #expect(fake.calls.isEmpty)
  }

  @Test("Строка громкости уходит исполнителю уровнем")
  func volume() {
    let fake = FakePerformer()
    PlayerActionRouter(performer: fake).perform(.setVolume(0.4), nowPlaying: nil)
    #expect(fake.calls == [.volume(0.4)])
  }

  @Test("🔈/🔊 строки громкости уходят исполнителю шагом: от какого уровня шагать, знает он")
  func stepVolume() {
    let fake = FakePerformer()
    let router = PlayerActionRouter(performer: fake)
    router.perform(.stepVolume(up: true), nowPlaying: nil)
    router.perform(.stepVolume(up: false), nowPlaying: nil)
    #expect(fake.calls == [.stepVolume(up: true), .stepVolume(up: false)])
  }

  @Test("Shuffle переключается от текущего режима: выкл → треки, вкл → выкл")
  func shuffle() {
    let fake = FakePerformer()
    let router = PlayerActionRouter(performer: fake)
    var info = NowPlayingInfo(bundleID: "com.apple.Music", title: "A", isPlaying: true)
    router.perform(.toggleShuffle, nowPlaying: info)
    info.shuffleMode = 3
    router.perform(.toggleShuffle, nowPlaying: info)
    #expect(fake.calls == [.shuffle(3), .shuffle(1)])
  }

  @Test("Repeat по кругу, как в Music: выкл → все → один → выкл")
  func repeatCycle() {
    let fake = FakePerformer()
    let router = PlayerActionRouter(performer: fake)
    for mode in [nil, 1, 3, 2] as [Int?] {
      var info = NowPlayingInfo(bundleID: "com.apple.Music", title: "A", isPlaying: true)
      info.repeatMode = mode
      router.perform(.cycleRepeat, nowPlaying: info)
    }
    #expect(fake.calls == [.repeatMode(3), .repeatMode(3), .repeatMode(2), .repeatMode(1)])
  }

  @Test("Перемотка уходит исполнителю позицией в секундах")
  func seek() {
    let fake = FakePerformer()
    PlayerActionRouter(performer: fake).perform(.seek(42), nowPlaying: nil)
    #expect(fake.calls == [.seek(42)])
  }
}
