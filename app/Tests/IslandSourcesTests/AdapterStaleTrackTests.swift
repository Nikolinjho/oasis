import IslandCore
import Testing
@testable import IslandSources

struct AdapterStaleTrackTests {
    @Test("Проверка старого трека — только после перезапуска, на пустой первой строке, если трек был")
    func startsStaleCheck() {
        #expect(AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 2, change: nil, hasTrack: true))
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 1, change: nil, hasTrack: true))
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: false, generation: 2, change: nil, hasTrack: true))
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 2, change: nil, hasTrack: false))
        let track = NowPlayingInfo(title: "T", isPlaying: true)
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 2, change: .newTrack(track), hasTrack: true))
    }
}
