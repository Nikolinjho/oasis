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
            .favorite, .media(.previousTrack), .media(.togglePlayPause), .media(.nextTrack), .toggleVolumeRow,
        ])
        #expect(PlayerControl.row(playing).map(\.isSide) == [true, false, false, false, true])
        #expect(PlayerControl.row(playing)[2].symbol == "pause.fill")
        var paused = playing
        paused.isPlaying = false
        #expect(PlayerControl.row(paused)[2].symbol == "play.fill")
        #expect(PlayerControl.row(nil).map(\.action).first == .openSource)
    }
}

struct VolumeRowTests {
    @Test("Строка громкости: уровень по точке касания и шаг ±10% у иконок, за краями зажат")
    func volumeRowLevel() {
        #expect(VolumeRow.level(at: 30, width: 120) == 0.25)
        #expect(VolumeRow.level(at: -10, width: 120) == 0)
        #expect(VolumeRow.level(at: 500, width: 120) == 1)
        #expect(VolumeRow.level(at: 10, width: 0) == 0)
        #expect(abs(VolumeRow.stepped(0.56, up: false) - 0.46) < 1e-9)
        #expect(VolumeRow.stepped(0.95, up: true) == 1)
        #expect(VolumeRow.stepped(0.04, up: false) == 0)
    }
}

struct PausedArtworkTests {
    @Test("На паузе обложка меньше, бледнее и тусклее, при игре как есть")
    func pausedLook() {
        let playing = PausedArtwork.look(isPlaying: true)
        let paused = PausedArtwork.look(isPlaying: false)
        #expect(playing == PausedArtwork.Look(scale: 1, saturation: 1, opacity: 1))
        #expect(paused.scale == 0.9)
        #expect(paused.saturation < 1)
        #expect(paused.opacity < 1)
    }
}
