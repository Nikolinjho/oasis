import CoreGraphics
import Foundation
import IslandCore
import Testing

@testable import Oasis

// .serialized: тесты пишут в UserDefaults(suiteName:) на диск через cfprefsd. Параллельно с другими
// тестами того же файла это иногда обгоняет removePersistentDomain (запись после удаления) и
// оставляет в ~/Library/Preferences файл с настоящими значениями, а не пустым доменом
@Suite(.serialized)
@MainActor
struct AppSettingsTests {
  /// Каждый суит уникален (UUID), но домен реально пишется в ~/Library/Preferences: без удаления
  /// он там и остаётся. Возвращаем имя вместе с defaults, чтобы тест мог убрать его за собой
  static func freshDefaults() -> (name: String, defaults: UserDefaults) {
    let name = "oasis-tests-\(UUID().uuidString)"
    return (name, UserDefaults(suiteName: name)!)
  }

  /// synchronize принудительно проталкивает запись перед удалением: без неё под параллельной
  /// нагрузкой swift test отложенный флаш cfprefsd иногда обгоняет removePersistentDomain
  static func cleanup(_ name: String, _ defaults: UserDefaults) {
    defaults.synchronize()
    defaults.removePersistentDomain(forName: name)
    defaults.synchronize()
  }

  @Test("По умолчанию как в Alcove: Expand on hover вкл, 0 с, главный экран, без виртуального выреза")
  func defaultsMatchAlcove() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.expandOnHover)
    #expect(settings.hoverDuration == 0)
    #expect(settings.display == .main)
    #expect(!settings.forceSimulatedNotch)
    #expect(settings.builtInNotch == nil)
    #expect(settings.playSounds)
  }

  @Test("Настройки переживают перезапуск, каждое изменение зовёт onChange")
  func persists() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    var calls = 0
    settings.onChange = { calls += 1 }
    settings.expandOnHover = false
    settings.hoverDuration = 0.3
    settings.forceSimulatedNotch = true
    settings.display = .named("DELL U2723QE")
    settings.builtInNotch = CGSize(width: 186, height: 32)
    settings.playSounds = false

    let again = AppSettings(defaults: defaults)
    #expect(!again.expandOnHover)
    #expect(again.hoverDuration == 0.3)
    #expect(again.forceSimulatedNotch)
    #expect(again.display == .named("DELL U2723QE"))
    #expect(again.builtInNotch == CGSize(width: 186, height: 32))
    #expect(!again.playSounds)
    // запомненный вырез — служебное значение, настройки он не меняет
    #expect(calls == 5)
  }

  @Test("Повторная запись того же значения onChange не зовёт")
  func noChangeNoCall() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    settings.expandOnHover = false
    settings.hoverDuration = 0.3
    settings.forceSimulatedNotch = true
    settings.display = .named("DELL U2723QE")
    var calls = 0
    settings.onChange = { calls += 1 }
    settings.expandOnHover = false
    settings.hoverDuration = 0.3
    settings.forceSimulatedNotch = true
    settings.display = .named("DELL U2723QE")
    #expect(calls == 0)
  }

  @Test("Сброс виртуального выреза убирает обе записи из UserDefaults")
  func clearingBuiltInNotchRemovesKeys() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    settings.builtInNotch = CGSize(width: 186, height: 32)
    settings.builtInNotch = nil
    #expect(settings.builtInNotch == nil)
    #expect(defaults.object(forKey: AppSettings.Key.builtInNotchWidth) == nil)
    #expect(defaults.object(forKey: AppSettings.Key.builtInNotchHeight) == nil)
  }

  @Test("Hide menu bar icon: по умолчанию выкл, переживает перезапуск, зовёт onChange")
  func hideMenuBarIcon() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(!settings.hideMenuBarIcon)
    var calls = 0
    settings.onChange = { calls += 1 }
    settings.hideMenuBarIcon = true
    #expect(calls == 1)
    #expect(AppSettings(defaults: defaults).hideMenuBarIcon)
  }

  @Test("Подгонка выреза: по умолчанию 0, зажата в −2…2, переживает перезапуск")
  func notchTuning() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.notchTuning == NotchTuning())
    settings.notchWidthOffset = -2
    settings.notchHeightOffset = 5
    #expect(settings.notchTuning == NotchTuning(width: -2, height: 2))
    let again = AppSettings(defaults: defaults)
    #expect(again.notchWidthOffset == -2)
  }

  @Test("Ползунок Notch width зажат: подсказка сразу с текущим значением, движение обновляет её, отпускание снимает (Task 17t)")
  func widthDragSendsTuningHint() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    settings.notchWidthOffset = -1
    var hints: [TuningHint?] = []
    settings.onTuningHint = { hints.append($0) }

    settings.notchWidthDragChanged(true)
    settings.notchWidthOffset = -2
    settings.notchWidthDragChanged(false)

    #expect(hints == [.width(-1), .width(-2), nil])
  }

  @Test("Ползунок Notch height зажат: та же подсказка, но .height (Task 17t)")
  func heightDragSendsTuningHint() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    var hints: [TuningHint?] = []
    settings.onTuningHint = { hints.append($0) }

    settings.notchHeightDragChanged(true)
    settings.notchHeightOffset = 1
    settings.notchHeightDragChanged(false)

    #expect(hints == [.height(0), .height(1), nil])
  }

  @Test("Значение слайдера меняется без зажатого ползунка (отладка, восстановление defaults): подсказки нет")
  func programmaticChangeDoesNotSendTuningHint() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    var calls = 0
    settings.onTuningHint = { _ in calls += 1 }
    settings.notchWidthOffset = -1
    settings.notchHeightOffset = 1
    #expect(calls == 0)
  }

  @Test("Оба ползунка Tuning зажаты разом: подсказка снимается, только когда отпущены оба (защита, не проверялось на Alcove)")
  func bothSlidersDraggedTogether() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    var hints: [TuningHint?] = []
    settings.onTuningHint = { hints.append($0) }

    settings.notchWidthDragChanged(true)
    settings.notchHeightDragChanged(true)
    settings.notchWidthDragChanged(false)
    #expect(hints.last == .height(0))
    settings.notchHeightDragChanged(false)
    // hints.last — TuningHint??: force-unwrap внешний Optional массива, чтобы «nil» здесь
    // сравнивался с последним отправленным значением, а не проверял, что массив пуст
    #expect(hints.last! == nil)
  }

  @Test("Hover-настройки попадают в конфиг машины, темп остаётся от базы")
  func machineConfig() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    settings.expandOnHover = false
    settings.hoverDuration = 0.2
    let config = settings.machineConfig(from: .user)
    #expect(!config.expandsOnHover)
    #expect(config.hoverDelay == .milliseconds(200))
    #expect(config.timeScale == IslandMachine.Config.user.timeScale)
  }

  @Test("Battery: по умолчанию как у Alcove, правила и вид собираются из настроек")
  func battery() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.batteryEnabled && settings.notifyLowPower && settings.warnLowBattery && settings.lowBatterySound)
    #expect(settings.batteryDuration == 5)
    #expect(settings.lowBatteryThreshold == 0.1)
    #expect(!settings.hideBatteryLabel && !settings.hideBatteryPercentage)
    #expect(settings.powerRules == PowerRules())

    settings.batteryDuration = 3.5
    settings.lowBatteryThreshold = 0.3
    settings.lowBatterySound = false
    settings.hideBatteryLabel = true
    #expect(settings.powerRules.lowBatteryThreshold == 0.3)
    #expect(settings.machineConfig(from: .user).alerts.batteryDuration == .milliseconds(3500))
    #expect(!settings.machineConfig(from: .user).alerts.lowBatterySound)
    #expect(settings.appearance.battery == BatteryAlertStyle(hidesLabel: true))
    #expect(AppSettings(defaults: defaults).lowBatteryThreshold == 0.3)
  }

  @Test("Connectivity: по умолчанию как у Alcove, порог 20%, длительность и звук уходят в правила")
  func connectivity() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.connectivityEnabled && settings.warnHeadphonesLowBattery && settings.headphonesLowBatterySound)
    #expect(settings.connectivityDuration == 5)
    #expect(settings.headphonesLowBatteryThreshold == 0.2)
    settings.connectivityDuration = 2.5
    settings.headphonesLowBatterySound = false
    let rules = settings.machineConfig(from: .user).alerts
    #expect(rules.connectivityDuration == .milliseconds(2500))
    #expect(!rules.headphonesLowBatterySound)
  }

  @Test("Display и Sound: по умолчанию как у Alcove, вид и длительности собираются из настроек")
  func huds() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.soundHUDEnabled && settings.displayHUDEnabled)
    #expect(settings.appearance.hud(.volume) == HUDAppearance(style: .decibel, icon: .device))
    #expect(settings.appearance.hud(.brightness) == HUDAppearance(style: .accent))
    settings.soundHUDDuration = 2
    settings.soundHUDStyle = .white
    settings.soundHUDPercentage = true
    settings.displayHUDSpeed = .instant
    settings.displayHUDHideLabel = true
    #expect(settings.machineConfig(from: .user).hudDurations.volume == .seconds(2))
    #expect(settings.appearance.hud(.volume) == HUDAppearance(style: .white, showsPercentage: true, icon: .device))
    #expect(settings.appearance.hud(.brightness) == HUDAppearance(style: .accent, hidesLabel: true, speed: .instant))
    #expect(AppSettings(defaults: defaults).soundHUDStyle == .white)
  }

  @Test("Now Playing: по умолчанию как у Alcove, правила уходят в машину")
  func nowPlayingRules() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.nowPlayingEnabled && settings.quickPeek && settings.peekOnMediaChange)
    #expect(!settings.hideWhileSourceActive)
    #expect(settings.idleDuration == 3 && settings.peekDuration == 2)
    #expect(settings.machineConfig(from: .user).nowPlaying == NowPlayingRules())
    settings.idleDuration = 0
    settings.peekDuration = 5
    settings.hideWhileSourceActive = true
    let rules = settings.machineConfig(from: .user).nowPlaying
    #expect(rules.idleDelay == .zero && rules.peekDuration == .seconds(5) && rules.hidesWhileSourceActive)
  }

  @Test("Вид Now Playing и источник: по умолчанию Colored, переворот и волна включены, Automatic · System")
  func nowPlayingLook() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.waveformStyle == .colored)
    #expect(settings.appearance.compactWaveform && settings.appearance.artworkFlip && !settings.appearance.hidesTitleExtras)
    #expect(settings.automaticMediaSource && settings.effectiveMediaSource == .system)
    settings.waveformStyle = .gradient
    settings.disableCompactWaveform = true
    settings.disableArtworkFlip = true
    settings.hideTitleExtras = true
    settings.automaticMediaSource = false
    settings.mediaSource = .yandexMusic
    #expect(settings.appearance.waveform == .gradient)
    #expect(!settings.appearance.compactWaveform && !settings.appearance.artworkFlip && settings.appearance.hidesTitleExtras)
    // Яндекс Музыки пока нет: выбранный недоступный источник читается как System
    #expect(settings.effectiveMediaSource == .system)
  }

  @Test("Доп. кнопка плеера: по умолчанию Shuffle, как controlChoice у Alcove")
  func playerControl() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.playerControl == .shuffle)
    settings.playerControl = .repeat
    #expect(settings.appearance.playerControl == .repeat)
  }

  @Test("Время справа от прогресса: по умолчанию остаток, как showRemainingTime = 1 у Alcove")
  func remainingTime() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.showRemainingTime && settings.appearance.showsRemainingTime)
    settings.showRemainingTime = false
    #expect(!settings.appearance.showsRemainingTime)
    // переживает перезапуск, как остальные настройки
    #expect(!AppSettings(defaults: defaults).showRemainingTime)
  }

  @Test("Idle Activity: по умолчанию Duo, Most Recent выкл, Force enable вкл, правила уходят в машину")
  func idleActivity() {
    let (name, defaults) = Self.freshDefaults()
    defer { Self.cleanup(name, defaults) }
    let settings = AppSettings(defaults: defaults)
    #expect(settings.idleActivity == .duo && !settings.mostRecentActivity && settings.forceEnableActivity)
    #expect(settings.machineConfig(from: .user).expanded == ExpandedRules())
    settings.idleActivity = .playing
    settings.mostRecentActivity = true
    #expect(settings.machineConfig(from: .user).expanded.idleActivity == .playing)
    #expect(settings.machineConfig(from: .user).expanded.mostRecent)
    #expect(AppSettings(defaults: defaults).idleActivity == .playing)
  }
}
