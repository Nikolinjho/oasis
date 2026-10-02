import Foundation
import Testing

@testable import AlcoveAnalog

@MainActor
struct DemoTracksTests {
  @Test("Демо-треки не замораживают elapsedAt: каждое обращение — свежая метка времени")
  func tracksStayFresh() async throws {
    let first = DemoTracks.all[0].elapsedAt
    try await Task.sleep(for: .milliseconds(5))
    let second = DemoTracks.all[0].elapsedAt
    #expect(second > first)

    let firstNoArtwork = DemoTracks.withoutArtwork.elapsedAt
    try await Task.sleep(for: .milliseconds(5))
    let secondNoArtwork = DemoTracks.withoutArtwork.elapsedAt
    #expect(secondNoArtwork > firstNoArtwork)
  }
}
