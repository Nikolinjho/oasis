import IslandCore
import Testing
@testable import IslandUI

struct PlayerControlTests {
    @Test("Левая кнопка: звезда у Apple Music, ссылка у остальных")
    func leadingControl() {
        let music = NowPlayingInfo(bundleID: "com.apple.Music", title: "A", isPlaying: true)
        let spotify = NowPlayingInfo(bundleID: "com.spotify.client", title: "A", isPlaying: true)
        #expect(PlayerControl.leading(music) == PlayerControl(symbol: "star.fill", action: .favorite, isSide: true))
        #expect(PlayerControl.leading(spotify) == PlayerControl(symbol: "link", action: .openSource, isSide: true))
        #expect(PlayerControl.leading(nil).action == .openSource)
    }

    @Test("Пять кнопок и их действия")
    func controls() {
        let playing = NowPlayingInfo(bundleID: "com.apple.Music", title: "A", isPlaying: true)
        #expect(PlayerControl.row(playing).map(\.action) == [
            .favorite, .media(.previousTrack), .media(.togglePlayPause), .media(.nextTrack), .chooseOutput,
        ])
        #expect(PlayerControl.row(playing).map(\.isSide) == [true, false, false, false, true])
        #expect(PlayerControl.row(playing)[2].symbol == "pause.fill")
        var paused = playing
        paused.isPlaying = false
        #expect(PlayerControl.row(paused)[2].symbol == "play.fill")
        #expect(PlayerControl.row(nil).map(\.action).first == .openSource)
    }
}
