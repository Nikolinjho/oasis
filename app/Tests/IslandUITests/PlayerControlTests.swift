import Foundation
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
    #expect(
      row.dropFirst().map { $0?.action } == [
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

  @Test("Подложка кнопки: активный Shuffle/Repeat светится сам, вывод — только при открытой строке громкости")
  func buttonBackground() {
    let activeShuffle = PlayerControl(symbol: "shuffle", action: .toggleShuffle, isSide: true, isActive: true)
    #expect(PlayerButton.showsBackground(activeShuffle, showsVolumeRow: false))
    let output = PlayerControl(symbol: "headphones", action: .toggleVolumeRow, isSide: true)
    #expect(!PlayerButton.showsBackground(output, showsVolumeRow: false))
    #expect(PlayerButton.showsBackground(output, showsVolumeRow: true))
    // подложка вывода при открытой строке громкости не значит, что control.isActive истинно:
    // точка под иконкой (рисуется отдельно от showsBackground) у него не появится
    #expect(!output.isActive)
  }

  @Test("Время справа: остаток или полная длительность (Alcove 1.7.9, 28.09)")
  func trailingTime() {
    #expect(ProgressRow.trailing(position: 61, duration: 263, remaining: true) == "-3:22")
    #expect(ProgressRow.trailing(position: 61, duration: 263, remaining: false) == "4:23")
  }

  @Test("Формат времени: m:ss до часа, дальше h:mm:ss — подкасты и видео длиннее 60 минут не съезжают в «75:12»")
  func formatLongMedia() {
    #expect(ProgressRow.format(0) == "0:00")
    #expect(ProgressRow.format(3599) == "59:59")
    #expect(ProgressRow.format(3600) == "1:00:00")
    #expect(ProgressRow.format(4512) == "1:15:12")
  }

  @Test("Остаток у двухчасового видео тоже в h:mm:ss")
  func remainingLongMedia() {
    // 2 ч видео (7200 с), позиция 3477 с — до конца 3723 с = 1:02:03
    #expect(ProgressRow.remaining(position: 3477, duration: 7200) == "-1:02:03")
    #expect(ProgressRow.trailing(position: 3477, duration: 7200, remaining: true) == "-1:02:03")
    #expect(ProgressRow.trailing(position: 3477, duration: 7200, remaining: false) == "2:00:00")
  }

  @Test("Перемотка: позиция по точке клика, за краями зажата")
  func seekPosition() {
    #expect(ProgressRow.seekPosition(at: 60, width: 240, duration: 200) == 50)
    #expect(ProgressRow.seekPosition(at: -5, width: 240, duration: 200) == 0)
    #expect(ProgressRow.seekPosition(at: 999, width: 240, duration: 200) == 200)
    #expect(ProgressRow.seekPosition(at: 10, width: 0, duration: 200) == 0)
  }

  @Test("Что показывать: перетаскивание важнее отложенного seek, тот — важнее позиции источника")
  func displayPosition() {
    let now = Date()
    // тянут прямо сейчас — неважно, что уже отправлен seek и что говорит источник
    #expect(
      ProgressRow.displayPosition(
        dragFraction: 0.5, pendingSeek: (10, now), sourcePosition: 5, duration: 100, isPlaying: true, now: now) == 50)
    // отложенный seek 2 с назад, играет — тикает свой отсчёт, а не источник
    #expect(
      ProgressRow.displayPosition(
        dragFraction: nil, pendingSeek: (10, now.addingTimeInterval(-2)), sourcePosition: 5, duration: 100,
        isPlaying: true, now: now) == 12)
    // тот же отложенный seek, но на паузе — отсчёт не идёт
    #expect(
      ProgressRow.displayPosition(
        dragFraction: nil, pendingSeek: (10, now.addingTimeInterval(-2)), sourcePosition: 5, duration: 100,
        isPlaying: false, now: now) == 10)
    // ни перетаскивания, ни отложенного seek — позиция источника
    #expect(
      ProgressRow.displayPosition(
        dragFraction: nil, pendingSeek: nil, sourcePosition: 5, duration: 100, isPlaying: true, now: now) == 5)
  }

  @Test("Позиция зажата в 0…duration: у конца трека отложенный seek не уходит за длительность")
  func displayPositionClamped() {
    let now = Date()
    #expect(
      ProgressRow.displayPosition(
        dragFraction: nil, pendingSeek: (99, now.addingTimeInterval(-2)), sourcePosition: 5, duration: 100,
        isPlaying: true, now: now) == 100)
    #expect(
      ProgressRow.displayPosition(
        dragFraction: nil, pendingSeek: nil, sourcePosition: -1, duration: 100, isPlaying: true, now: now) == 0)
    // длительность неизвестна — зажимать сверху не по чему
    #expect(
      ProgressRow.displayPosition(
        dragFraction: nil, pendingSeek: nil, sourcePosition: 42, duration: 0, isPlaying: true, now: now) == 42)
  }

  @Test("Удержание seek: источник прислал старую позицию — держим цель, близкую к цели — отпускаем")
  func holdsSeek() {
    let sent = Date()
    // YouTube переопубликовал позицию до перемотки
    #expect(ProgressRow.holdsSeek(target: 120, sourcePosition: 30, sentAt: sent, now: sent.addingTimeInterval(0.4)))
    // источник подтвердил: позиция в пределах 1.5 с от цели
    #expect(!ProgressRow.holdsSeek(target: 120, sourcePosition: 121.2, sentAt: sent, now: sent.addingTimeInterval(0.4)))
    #expect(!ProgressRow.holdsSeek(target: 120, sourcePosition: 119, sentAt: sent, now: sent.addingTimeInterval(0.4)))
    // за 3 с не подтвердил — дальше верим источнику
    #expect(!ProgressRow.holdsSeek(target: 120, sourcePosition: 30, sentAt: sent, now: sent.addingTimeInterval(3.1)))
  }
}

struct VolumeRowTests {
  @Test("Строка громкости: уровень по точке касания, за краями зажат")
  func volumeRowLevel() {
    #expect(VolumeRow.level(at: 30, width: 120) == 0.25)
    #expect(VolumeRow.level(at: -10, width: 120) == 0)
    #expect(VolumeRow.level(at: 500, width: 120) == 1)
    #expect(VolumeRow.level(at: 10, width: 0) == 0)
  }
}

struct PausedArtworkTests {
  @Test("На паузе обложка меньше, бледнее и тусклее, при игре как есть")
  func pausedLook() {
    let playing = PausedArtwork.look(isPlaying: true)
    let paused = PausedArtwork.look(isPlaying: false)
    #expect(playing == PausedArtwork.Look(scale: 1, saturation: 1, opacity: 1))
    #expect(paused.scale == 0.83)
    #expect(paused.saturation < 1)
    #expect(paused.opacity < 1)
  }
}
