import Foundation
import Testing

@testable import IslandCore

struct NowPlayingInfoTests {
  static let start = Date(timeIntervalSince1970: 1_000_000)

  static func info(playing: Bool, elapsed: TimeInterval?, duration: TimeInterval? = 240) -> NowPlayingInfo {
    NowPlayingInfo(title: "Fire", artist: "Artist A", isPlaying: playing, duration: duration, elapsed: elapsed, elapsedAt: start)
  }

  @Test("У играющего трека позиция растёт со временем")
  func playingAdvances() {
    #expect(Self.info(playing: true, elapsed: 60).position(at: Self.start.addingTimeInterval(5)) == 65)
  }

  @Test("Позиция не выходит за длительность")
  func clampedToDuration() {
    #expect(Self.info(playing: true, elapsed: 238).position(at: Self.start.addingTimeInterval(10)) == 240)
  }

  @Test("На паузе позиция стоит")
  func pausedStays() {
    #expect(Self.info(playing: false, elapsed: 60).position(at: Self.start.addingTimeInterval(5)) == 60)
  }

  @Test("Без elapsed позиции нет")
  func noElapsed() {
    #expect(Self.info(playing: true, elapsed: nil).position(at: Self.start) == nil)
  }

  @Test("Ключ трека из названия, артиста и альбома")
  func trackKey() {
    #expect(NowPlayingInfo(title: "Fire", artist: "A", album: "B", isPlaying: true).trackKey == "Fire|A|B")
    #expect(NowPlayingInfo(title: "Fire", isPlaying: true).trackKey == "Fire||")
  }
}
