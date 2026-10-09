import Foundation
import Testing

@testable import IslandCore

struct PlayerCapabilitiesTests {
  @Test("System сохраняет доступность команд и прежние циклы режимов")
  func systemFallback() {
    let info = NowPlayingInfo(bundleID: NowPlayingInfo.musicBundleID, title: "A", isPlaying: true)
    #expect(info.capabilities.canPlayPause)
    #expect(info.capabilities.canNext)
    #expect(info.capabilities.canPrevious)
    #expect(info.capabilities.canSeek)
    #expect(info.capabilities.canFavorite)
    #expect(info.capabilities.shuffleModes == [1, 3])
    #expect(info.capabilities.repeatModes == [1, 3, 2])
    #expect(!info.capabilities.requiresConfirmation)
  }

  @Test("Возможности System учитывают canSkip и меняются вместе с ним")
  func mutableSystemFallback() {
    var info = NowPlayingInfo(title: "A", isPlaying: true, canSkip: false)
    #expect(!info.capabilities.canNext)
    #expect(!info.capabilities.canPrevious)
    #expect(!info.capabilities.canFavorite)
    info.canSkip = true
    #expect(info.capabilities.canNext)
    #expect(info.capabilities.canPrevious)
  }

  @Test("У браузера нет дополнительных команд shuffle, repeat и favorite")
  func browserFallback() {
    let info = NowPlayingInfo(bundleID: NowPlayingInfo.musicBundleID, title: "A", isPlaying: true, isBrowser: true)
    #expect(info.capabilities.canPlayPause)
    #expect(info.capabilities.canSeek)
    #expect(!info.capabilities.canFavorite)
    #expect(info.capabilities.shuffleModes.isEmpty)
    #expect(info.capabilities.repeatModes.isEmpty)
  }

  @Test("Явные возможности сохраняют независимую доступность следующего и предыдущего трека")
  func explicitCapabilities() {
    let capabilities = PlayerCapabilities(
      canPlayPause: false, canNext: true, canPrevious: false, canSeek: false,
      canFavorite: true, shuffleModes: [], repeatModes: [1, 2], requiresConfirmation: true)
    let info = NowPlayingInfo(title: "A", isPlaying: true, canSkip: false, isBrowser: true, capabilities: capabilities)
    #expect(info.capabilities == capabilities)
    #expect(info.isFavorite == nil)
  }

  @Test("Идентификатор источника сохраняет ключ трека при обновлении метаданных и обложки")
  func stableTrackIdentity() {
    var info = NowPlayingInfo(
      bundleID: "ru.yandex.desktop.music", title: "A", isPlaying: true, sourceTrackID: "42", isFavorite: false)
    let key = info.trackKey
    info.title = "Полное название"
    info.artist = "Исполнитель"
    info.album = "Альбом"
    info.artwork = Data([1, 2])
    #expect(info.trackKey == key)
    #expect(info.isFavorite == false)
    info.sourceTrackID = "43"
    #expect(info.trackKey != key)
    info.sourceTrackID = "42"
    info.bundleID = "another.source"
    #expect(info.trackKey != key)
  }

  @Test("Повтор проходит только поддержанные режимы и замыкается в цикл")
  func supportedRepeatCycle() {
    let capabilities = PlayerCapabilities(
      canPlayPause: true, canNext: true, canPrevious: false, canSeek: true,
      canFavorite: false, shuffleModes: [1, 3], repeatModes: [1, 2])
    var info = NowPlayingInfo(title: "A", isPlaying: true, capabilities: capabilities)
    #expect(info.nextSupportedRepeatMode == 2)
    info.repeatMode = 2
    #expect(info.nextSupportedRepeatMode == 1)
    info.repeatMode = 3
    #expect(info.nextSupportedRepeatMode == 1)
  }

  @Test("Яндекс Музыка доступна для ручного выбора")
  func yandexSourceAvailable() {
    #expect(MediaSourceChoice.yandexMusic.isAvailable)
    #expect(MediaSourceChoice.system.isAvailable)
  }

  @Test("System сохраняет прежний переход для неизвестных кодов режимов")
  func legacyUnknownModes() {
    let info = NowPlayingInfo(title: "A", isPlaying: true, shuffleMode: 0, repeatMode: 0)
    #expect(info.nextSupportedShuffleMode == info.nextShuffleMode)
    #expect(info.nextSupportedRepeatMode == NowPlayingInfo.nextRepeatMode(after: info.repeatMode))
  }

}
