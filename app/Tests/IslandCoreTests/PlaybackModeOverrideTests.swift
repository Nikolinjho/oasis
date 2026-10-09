import Foundation
import Testing

@testable import IslandCore

struct PlaybackModeOverrideTests {
  let now = Date(timeIntervalSinceReferenceDate: 0)

  func music(shuffle: Int? = 1, repeatMode: Int? = 1, bundleID: String = "com.apple.Music") -> NowPlayingInfo {
    NowPlayingInfo(bundleID: bundleID, title: "A", isPlaying: true, shuffleMode: shuffle, repeatMode: repeatMode)
  }

  @Test("Клик сразу меняет показанный режим, не дожидаясь payload")
  func appliesImmediately() {
    var override = PlaybackModeOverride()
    let info = music()
    override.toggleShuffle(info, at: now)
    override.cycleRepeat(info, at: now)
    let shown = override.applied(to: info)
    #expect(shown.isShuffling)
    #expect(shown.repeatMode == 3)
  }

  @Test("Двойной клик считает от уже показанного состояния, а не от старого payload")
  func doubleClick() {
    var override = PlaybackModeOverride()
    let info = music()
    override.toggleShuffle(info, at: now)
    override.toggleShuffle(override.applied(to: info), at: now)
    #expect(!override.applied(to: info).isShuffling)
    override.cycleRepeat(info, at: now)
    override.cycleRepeat(override.applied(to: info), at: now)
    #expect(override.applied(to: info).repeatMode == 2)
  }

  @Test("Payload подтвердил значение — override снят")
  func confirmed() {
    var override = PlaybackModeOverride()
    override.toggleShuffle(music(), at: now)
    override.reconcile(with: music(shuffle: 3), now: now.addingTimeInterval(0.3))
    #expect(override.shuffle == nil)
  }

  @Test("Таймер снимает только просроченное: старый payload, совпавший с кликом, подтверждением не считается")
  func expireIgnoresStalePayload() {
    var override = PlaybackModeOverride()
    let info = music(shuffle: 1)
    override.toggleShuffle(info, at: now)
    override.toggleShuffle(override.applied(to: info), at: now.addingTimeInterval(0.1))
    override.expire(for: info, now: now.addingTimeInterval(0.2))
    #expect(override.shuffle?.mode == 1)
    override.expire(for: info, now: now.addingTimeInterval(2.2))
    #expect(override.shuffle == nil)
  }

  @Test("Payload со старым значением до таймаута override не снимает, после 2 с — снимает")
  func timeout() {
    var override = PlaybackModeOverride()
    override.toggleShuffle(music(), at: now)
    override.reconcile(with: music(shuffle: 1), now: now.addingTimeInterval(0.3))
    #expect(override.applied(to: music(shuffle: 1)).isShuffling)
    override.reconcile(with: music(shuffle: 1), now: now.addingTimeInterval(2.1))
    #expect(override.shuffle == nil)
    #expect(!override.applied(to: music(shuffle: 1)).isShuffling)
  }

  @Test("Источник без shuffleMode/repeatMode: кнопка показывает локальное состояние и после таймаута")
  func sourceWithoutModes() {
    var override = PlaybackModeOverride()
    let info = music(shuffle: nil, repeatMode: nil)
    override.toggleShuffle(info, at: now)
    override.reconcile(with: info, now: now.addingTimeInterval(10))
    #expect(override.applied(to: info).isShuffling)
    override.toggleShuffle(override.applied(to: info), at: now.addingTimeInterval(11))
    #expect(!override.applied(to: info).isShuffling)
  }

  @Test("Сменился источник — локальное состояние прежнего не переносится")
  func sourceChanged() {
    var override = PlaybackModeOverride()
    override.toggleShuffle(music(shuffle: nil), at: now)
    let spotify = music(shuffle: nil, bundleID: "com.spotify.client")
    override.reconcile(with: spotify, now: now.addingTimeInterval(0.1))
    #expect(override.shuffle == nil)
    #expect(!override.applied(to: spotify).isShuffling)
  }

  @Test("Ближайший момент, когда override истечёт: только у режимов, которые источник присылает")
  func nextExpiry() {
    var override = PlaybackModeOverride()
    #expect(override.nextExpiry(for: music()) == nil)
    override.toggleShuffle(music(), at: now)
    #expect(override.nextExpiry(for: music()) == now.addingTimeInterval(PlaybackModeOverride.timeout))
    #expect(override.nextExpiry(for: music(shuffle: nil)) == nil)
  }

  func yandex(shuffle: Int? = nil, repeatMode: Int? = nil, modes: [Int] = [1, 2]) -> NowPlayingInfo {
    NowPlayingInfo(
      bundleID: "ru.yandex.desktop.music", title: "A", isPlaying: true,
      shuffleMode: shuffle, repeatMode: repeatMode,
      capabilities: PlayerCapabilities(
        canPlayPause: true, canNext: true, canPrevious: false, canSeek: true,
        canFavorite: true, shuffleModes: [1, 3], repeatModes: modes, requiresConfirmation: true))
  }

  @Test("Неподдержанные режимы не создают оптимистичного состояния")
  func unsupportedModes() {
    var override = PlaybackModeOverride()
    let browser = NowPlayingInfo(title: "A", isPlaying: true, isBrowser: true)
    override.toggleShuffle(browser, at: now)
    override.cycleRepeat(browser, at: now)
    #expect(override.shuffle == nil)
    #expect(override.repeatMode == nil)
    override.cycleRepeat(yandex(modes: [1]), at: now)
    #expect(override.repeatMode == nil)
  }

  @Test("Оптимистичный повтор использует цикл возможностей источника")
  func supportedRepeatModes() {
    var override = PlaybackModeOverride()
    let info = yandex()
    override.cycleRepeat(info, at: now)
    #expect(override.repeatMode?.mode == 2)
    override.cycleRepeat(override.applied(to: info), at: now)
    #expect(override.repeatMode?.mode == 1)
  }

  @Test("Яндекс без полей режимов требует подтверждения и назначает таймер")
  func missingConfirmationExpiry() {
    var override = PlaybackModeOverride()
    let info = yandex()
    override.toggleShuffle(info, at: now)
    override.cycleRepeat(info, at: now.addingTimeInterval(0.1))
    #expect(override.nextExpiry(for: info) == now.addingTimeInterval(PlaybackModeOverride.timeout))
    override.expire(for: info, now: now.addingTimeInterval(2))
    #expect(override.shuffle == nil)
    #expect(override.repeatMode != nil)
    override.expire(for: info, now: now.addingTimeInterval(2.1))
    #expect(override.repeatMode == nil)
  }

  @Test("Payload без подтверждения снимает ожидание Яндекса по таймауту")
  func missingConfirmationReconcile() {
    var override = PlaybackModeOverride()
    let info = yandex()
    override.toggleShuffle(info, at: now)
    override.cycleRepeat(info, at: now)
    override.reconcile(with: info, now: now.addingTimeInterval(0.5))
    #expect(override.shuffle != nil)
    #expect(override.repeatMode != nil)
    override.reconcile(with: info, now: now.addingTimeInterval(2))
    #expect(override.shuffle == nil)
    #expect(override.repeatMode == nil)
  }

  @Test("Отказ команды снимает только ожидание соответствующего режима")
  func rejectedCommandClearsOnlyItsMode() {
    var override = PlaybackModeOverride()
    let info = yandex()
    override.toggleShuffle(info, at: now)
    override.cycleRepeat(info, at: now)
    override.clear(.toggleShuffle)
    #expect(override.shuffle == nil)
    #expect(override.repeatMode != nil)
    override.clear(.favorite)
    #expect(override.repeatMode != nil)
    override.clear(.cycleRepeat)
    #expect(override.repeatMode == nil)
  }

  @Test("Исчезнувшая возможность снимает оптимистичный режим")
  func removedCapability() {
    var override = PlaybackModeOverride()
    var info = yandex()
    override.toggleShuffle(info, at: now)
    override.cycleRepeat(info, at: now)
    info.capabilities.shuffleModes = []
    info.capabilities.repeatModes = []
    #expect(override.applied(to: info).shuffleMode == nil)
    #expect(override.applied(to: info).repeatMode == nil)
    override.reconcile(with: info, now: now.addingTimeInterval(0.1))
    #expect(override.shuffle == nil)
    #expect(override.repeatMode == nil)
  }

}
