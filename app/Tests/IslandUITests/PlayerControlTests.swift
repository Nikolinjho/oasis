import IslandCore
import Testing
@testable import IslandUI

struct PlayerControlTests {
    static func music(_ extra: (inout NowPlayingInfo) -> Void = { _ in }) -> NowPlayingInfo {
        var info = NowPlayingInfo(bundleID: "com.apple.Music", title: "A", isPlaying: true)
        extra(&info)
        return info
    }

    @Test("Пять мест: доп. кнопка, ⏪, ⏸, ⏩, вывод с глифом устройства (Alcove 1.7.9, 28.09)")
    func controls() {
        let row = PlayerControl.row(Self.music(), extra: .shuffle, outputSymbol: "headphones")
        #expect(row.count == 5)
        #expect(row[0]?.action == .toggleShuffle)
        #expect(row.dropFirst().map { $0?.action } == [
            .media(.previousTrack), .media(.togglePlayPause), .media(.nextTrack), .toggleVolumeRow,
        ])
        #expect(row[2]?.symbol == "pause.fill")
        #expect(row[4]?.symbol == "headphones")
        #expect(row.compactMap { $0 }.allSatisfy { $0.isEnabled })
    }

    @Test("Браузер: слот доп. кнопки пуст, ⏪⏩ тусклые, в Duo тоже")
    func browser() {
        var web = NowPlayingInfo(bundleID: "com.google.Chrome", title: "Video", isPlaying: true)
        web.isBrowser = true
        web.canSkip = false
        let row = PlayerControl.row(web, extra: .shuffle, outputSymbol: "laptopcomputer")
        #expect(row[0] == nil)
        #expect(row.dropFirst().map { $0?.isEnabled } == [false, true, false, true])
        #expect(DuoControl.row(web).map(\.isEnabled) == [false, true, false])
    }

    @Test("Доп. кнопка по выбору: Shuffle и Repeat со своим состоянием, Favorite только у Music, Copy — нет")
    func extraChoice() {
        let shuffling = PlayerControl.extra(Self.music { $0.shuffleMode = 3 }, choice: .shuffle)
        #expect(shuffling?.symbol == "shuffle" && shuffling?.isActive == true)
        #expect(PlayerControl.extra(Self.music { $0.shuffleMode = 1 }, choice: .shuffle)?.isActive == false)
        let one = PlayerControl.extra(Self.music { $0.repeatMode = 2 }, choice: .repeat)
        #expect(one?.symbol == "repeat.1" && one?.action == .cycleRepeat && one?.isActive == true)
        #expect(PlayerControl.extra(Self.music(), choice: .repeat)?.symbol == "repeat")
        #expect(PlayerControl.extra(Self.music(), choice: .favorite)?.action == .favorite)
        let other = NowPlayingInfo(bundleID: "ru.yandex.desktop.music", title: "A", isPlaying: true)
        #expect(PlayerControl.extra(other, choice: .favorite) == nil)
        #expect(PlayerControl.extra(Self.music(), choice: .copy) == nil)
        #expect(PlayerControl.extra(nil, choice: .shuffle) == nil)
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
