import Combine
import CoreGraphics
import Foundation
import IslandCore

/// Настройки приложения в UserDefaults. Изменение сразу уходит в onChange: AppDelegate применяет его
/// к машине острова. Выбор экрана (display) пока никуда не применяется — отдельная задача, P2.
/// ObservableObject: окно настроек держит его через @ObservedObject
@MainActor
final class AppSettings: ObservableObject {  // swiftlint:disable:this type_body_length - по свойству на настройку
  enum Key {
    static let expandOnHover = "expandOnHover"
    static let hoverDuration = "hoverDuration"
    static let forceSimulatedNotch = "forceSimulatedNotch"
    static let display = "display"
    static let builtInNotchWidth = "builtInNotchWidth"
    static let builtInNotchHeight = "builtInNotchHeight"
    static let playSounds = "playSounds"
    static let hideMenuBarIcon = "hideMenuBarIcon"
    static let notchWidthOffset = "notchWidthOffset"
    static let notchHeightOffset = "notchHeightOffset"
    static let batteryEnabled = "batteryEnabled"
    static let batteryDuration = "batteryDuration"
    static let notifyLowPower = "notifyLowPower"
    static let warnLowBattery = "warnLowBattery"
    static let lowBatteryThreshold = "lowBatteryThreshold"
    static let lowBatterySound = "lowBatterySound"
    static let hideBatteryLabel = "hideBatteryLabel"
    static let hideBatteryPercentage = "hideBatteryPercentage"
    static let connectivityEnabled = "connectivityEnabled"
    static let connectivityDuration = "connectivityDuration"
    static let warnHeadphonesLowBattery = "warnHeadphonesLowBattery"
    static let headphonesLowBatteryThreshold = "headphonesLowBatteryThreshold"
    static let headphonesLowBatterySound = "headphonesLowBatterySound"
    static let soundHUDEnabled = "soundHUDEnabled"
    static let soundHUDDuration = "soundHUDDuration"
    static let soundHUDStyle = "soundHUDStyle"
    static let soundHUDPercentage = "soundHUDPercentage"
    static let soundHUDHideLabel = "soundHUDHideLabel"
    static let soundHUDSpeed = "soundHUDSpeed"
    static let soundHUDIcon = "soundHUDIcon"
    static let displayHUDEnabled = "displayHUDEnabled"
    static let displayHUDDuration = "displayHUDDuration"
    static let displayHUDStyle = "displayHUDStyle"
    static let displayHUDPercentage = "displayHUDPercentage"
    static let displayHUDHideLabel = "displayHUDHideLabel"
    static let displayHUDSpeed = "displayHUDSpeed"
    static let nowPlayingEnabled = "nowPlayingEnabled"
    static let idleDuration = "idleDuration"
    static let quickPeek = "quickPeek"
    static let peekOnMediaChange = "peekOnMediaChange"
    static let peekDuration = "peekDuration"
    static let hideWhileSourceActive = "hideWhileSourceActive"
    static let waveformStyle = "waveformStyle"
    static let disableCompactWaveform = "disableCompactWaveform"
    static let disableArtworkFlip = "disableArtworkFlip"
    static let hideTitleExtras = "hideTitleExtras"
    static let automaticMediaSource = "automaticMediaSource"
    static let mediaSource = "mediaSource"
    static let playerControl = "playerControl"
    static let showRemainingTime = "showRemainingTime"
    static let idleActivity = "idleActivity"
    static let mostRecentActivity = "mostRecentActivity"
    static let forceEnableActivity = "forceEnableActivity"
    static let swipeToDismiss = "swipeToDismiss"
    static let naturalMovement = "naturalMovement"
  }

  var onChange: () -> Void = {}
  /// Ползунок Notch width/height зажат (значение) или отпущен (nil): Task 17t, остров показывает
  /// красную подложку-подсказку. AppDelegate шлёт это напрямую в store.send(.tuningHintChanged(...))
  var onTuningHint: (TuningHint?) -> Void = { _ in }
  /// Зажат ли сейчас каждый из двух ползунков Tuning: onTuningHint(nil) шлётся, только когда отпущены оба
  private var isDraggingWidth = false
  private var isDraggingHeight = false
  private let defaults: UserDefaults

  /// General → Expand on hover, по умолчанию вкл
  @Published var expandOnHover: Bool {
    didSet {
      guard oldValue != expandOnHover else { return }
      defaults.set(expandOnHover, forKey: Key.expandOnHover)
      onChange()
    }
  }
  /// General → Hover duration, 0…0.6 с, по умолчанию 0
  @Published var hoverDuration: Double {
    didSet {
      guard oldValue != hoverDuration else { return }
      defaults.set(hoverDuration, forKey: Key.hoverDuration)
      onChange()
    }
  }
  /// General → Force simulated notch: виртуальный вырез на экране без настоящего
  @Published var forceSimulatedNotch: Bool {
    didSet {
      guard oldValue != forceSimulatedNotch else { return }
      defaults.set(forceSimulatedNotch, forKey: Key.forceSimulatedNotch)
      onChange()
    }
  }
  /// General → Display on
  @Published var display: DisplayChoice {
    didSet {
      guard oldValue != display else { return }
      defaults.set(display.storageValue, forKey: Key.display)
      onChange()
    }
  }
  /// Звуки уведомлений: календарь, низкий заряд, энергосбережение. По умолчанию вкл, как у Alcove
  @Published var playSounds: Bool {
    didSet {
      guard oldValue != playSounds else { return }
      defaults.set(playSounds, forKey: Key.playSounds)
      onChange()
    }
  }
  /// General → Hide menu bar icon (ключ Alcove settings.general.hideMenuBarIcon). Меню остаётся по правому
  /// клику на острове: иконку в menu bar часто закрывает компакт
  @Published var hideMenuBarIcon: Bool {
    didSet {
      guard oldValue != hideMenuBarIcon else { return }
      defaults.set(hideMenuBarIcon, forKey: Key.hideMenuBarIcon)
      onChange()
    }
  }

  /// General → Tuning → Notch width, pt, −2…2
  @Published var notchWidthOffset: Double {
    didSet {
      guard oldValue != notchWidthOffset else { return }
      defaults.set(notchWidthOffset, forKey: Key.notchWidthOffset)
      onChange()
      // подсказку двигаем, только пока ползунок реально зажат (isDraggingWidth): значение,
      // выставленное отладкой или восстановленное из defaults, подсказку сама не включает
      if isDraggingWidth { onTuningHint(.width(Int(notchWidthOffset))) }
    }
  }
  /// General → Tuning → Notch height, pt, −2…2
  @Published var notchHeightOffset: Double {
    didSet {
      guard oldValue != notchHeightOffset else { return }
      defaults.set(notchHeightOffset, forKey: Key.notchHeightOffset)
      onChange()
      if isDraggingHeight { onTuningHint(.height(Int(notchHeightOffset))) }
    }
  }

  /// SliderRow(Notch width).onEditingChanged (Task 17t): зажали — подсказка сразу с текущим значением,
  /// отпустили — подсказка снимается, если второй ползунок Tuning не зажат тоже
  func notchWidthDragChanged(_ editing: Bool) {
    isDraggingWidth = editing
    onTuningHint(editing ? .width(Int(notchWidthOffset)) : (isDraggingHeight ? .height(Int(notchHeightOffset)) : nil))
  }

  /// То же для Notch height
  func notchHeightDragChanged(_ editing: Bool) {
    isDraggingHeight = editing
    onTuningHint(editing ? .height(Int(notchHeightOffset)) : (isDraggingWidth ? .width(Int(notchWidthOffset)) : nil))
  }

  // Battery (ui-inspection 1.3). batteryDuration и enableBattery — единственные подтверждённые ключи Alcove
  @Published var batteryEnabled: Bool { didSet { save(oldValue, batteryEnabled, Key.batteryEnabled) } }
  /// 2.5…6 с, шаг 0.5
  @Published var batteryDuration: Double { didSet { save(oldValue, batteryDuration, Key.batteryDuration) } }
  @Published var notifyLowPower: Bool { didSet { save(oldValue, notifyLowPower, Key.notifyLowPower) } }
  @Published var warnLowBattery: Bool { didSet { save(oldValue, warnLowBattery, Key.warnLowBattery) } }
  /// 0.1, 0.2 или 0.3
  @Published var lowBatteryThreshold: Double { didSet { save(oldValue, lowBatteryThreshold, Key.lowBatteryThreshold) } }
  @Published var lowBatterySound: Bool { didSet { save(oldValue, lowBatterySound, Key.lowBatterySound) } }
  @Published var hideBatteryLabel: Bool { didSet { save(oldValue, hideBatteryLabel, Key.hideBatteryLabel) } }
  @Published var hideBatteryPercentage: Bool { didSet { save(oldValue, hideBatteryPercentage, Key.hideBatteryPercentage) } }

  // Connectivity (ui-inspection 1.4)
  @Published var connectivityEnabled: Bool { didSet { save(oldValue, connectivityEnabled, Key.connectivityEnabled) } }
  /// 2.5…6 с, шаг 0.5
  @Published var connectivityDuration: Double { didSet { save(oldValue, connectivityDuration, Key.connectivityDuration) } }
  @Published var warnHeadphonesLowBattery: Bool {
    didSet { save(oldValue, warnHeadphonesLowBattery, Key.warnHeadphonesLowBattery) }
  }
  /// 0.1, 0.2 или 0.3, по умолчанию 0.2 (у Battery 0.1)
  @Published var headphonesLowBatteryThreshold: Double {
    didSet { save(oldValue, headphonesLowBatteryThreshold, Key.headphonesLowBatteryThreshold) }
  }
  @Published var headphonesLowBatterySound: Bool {
    didSet { save(oldValue, headphonesLowBatterySound, Key.headphonesLowBatterySound) }
  }

  // Sound (ui-inspection 1.7)
  @Published var soundHUDEnabled: Bool { didSet { save(oldValue, soundHUDEnabled, Key.soundHUDEnabled) } }
  /// 1, 1.5 или 2 с
  @Published var soundHUDDuration: Double { didSet { save(oldValue, soundHUDDuration, Key.soundHUDDuration) } }
  @Published var soundHUDStyle: HUDBarStyle { didSet { saveRaw(oldValue, soundHUDStyle, Key.soundHUDStyle) } }
  @Published var soundHUDPercentage: Bool { didSet { save(oldValue, soundHUDPercentage, Key.soundHUDPercentage) } }
  @Published var soundHUDHideLabel: Bool { didSet { save(oldValue, soundHUDHideLabel, Key.soundHUDHideLabel) } }
  @Published var soundHUDSpeed: HUDSpeed { didSet { saveRaw(oldValue, soundHUDSpeed, Key.soundHUDSpeed) } }
  @Published var soundHUDIcon: HUDIcon { didSet { saveRaw(oldValue, soundHUDIcon, Key.soundHUDIcon) } }
  // Display (ui-inspection 1.6)
  @Published var displayHUDEnabled: Bool { didSet { save(oldValue, displayHUDEnabled, Key.displayHUDEnabled) } }
  @Published var displayHUDDuration: Double { didSet { save(oldValue, displayHUDDuration, Key.displayHUDDuration) } }
  @Published var displayHUDStyle: HUDBarStyle { didSet { saveRaw(oldValue, displayHUDStyle, Key.displayHUDStyle) } }
  @Published var displayHUDPercentage: Bool { didSet { save(oldValue, displayHUDPercentage, Key.displayHUDPercentage) } }
  @Published var displayHUDHideLabel: Bool { didSet { save(oldValue, displayHUDHideLabel, Key.displayHUDHideLabel) } }
  @Published var displayHUDSpeed: HUDSpeed { didSet { saveRaw(oldValue, displayHUDSpeed, Key.displayHUDSpeed) } }
  // Now Playing (ui-inspection 1.8)
  @Published var nowPlayingEnabled: Bool { didSet { save(oldValue, nowPlayingEnabled, Key.nowPlayingEnabled) } }
  /// Idle duration, 0…10 с, шаг 1
  @Published var idleDuration: Double { didSet { save(oldValue, idleDuration, Key.idleDuration) } }
  @Published var quickPeek: Bool { didSet { save(oldValue, quickPeek, Key.quickPeek) } }
  /// When media changes
  @Published var peekOnMediaChange: Bool { didSet { save(oldValue, peekOnMediaChange, Key.peekOnMediaChange) } }
  /// Peek duration, 1…6 с, шаг 1
  @Published var peekDuration: Double { didSet { save(oldValue, peekDuration, Key.peekDuration) } }
  @Published var hideWhileSourceActive: Bool { didSet { save(oldValue, hideWhileSourceActive, Key.hideWhileSourceActive) } }
  @Published var waveformStyle: WaveformStyle { didSet { saveRaw(oldValue, waveformStyle, Key.waveformStyle) } }
  @Published var disableCompactWaveform: Bool { didSet { save(oldValue, disableCompactWaveform, Key.disableCompactWaveform) } }
  @Published var disableArtworkFlip: Bool { didSet { save(oldValue, disableArtworkFlip, Key.disableArtworkFlip) } }
  @Published var hideTitleExtras: Bool { didSet { save(oldValue, hideTitleExtras, Key.hideTitleExtras) } }
  /// Source → Automatic (automaticMusicApp = 1 у Alcove, ui-inspection 6)
  @Published var automaticMediaSource: Bool { didSet { save(oldValue, automaticMediaSource, Key.automaticMediaSource) } }
  @Published var mediaSource: MediaSourceChoice { didSet { saveRaw(oldValue, mediaSource, Key.mediaSource) } }
  /// Now Playing → доп. кнопка плеера. По умолчанию Shuffle: controlChoice = shuffle у Alcove
  @Published var playerControl: PlayerExtraControl { didSet { saveRaw(oldValue, playerControl, Key.playerControl) } }
  /// Клик по времени плеера переключает её. showRemainingTime = 1 у Alcove по умолчанию
  @Published var showRemainingTime: Bool { didSet { save(oldValue, showRemainingTime, Key.showRemainingTime) } }

  // General → Idle Activity (ui-inspection 1.2). mostRecentActivity — ключ Alcove
  @Published var idleActivity: IdleActivity { didSet { saveRaw(oldValue, idleActivity, Key.idleActivity) } }
  @Published var mostRecentActivity: Bool { didSet { save(oldValue, mostRecentActivity, Key.mostRecentActivity) } }
  @Published var forceEnableActivity: Bool { didSet { save(oldValue, forceEnableActivity, Key.forceEnableActivity) } }

  // General → Gestures (ui-inspection 1.2)
  @Published var swipeToDismiss: Bool { didSet { save(oldValue, swipeToDismiss, Key.swipeToDismiss) } }
  @Published var naturalMovement: Bool { didSet { save(oldValue, naturalMovement, Key.naturalMovement) } }

  /// Источник, который реально запускается: Automatic и недоступные пока источники — System
  var effectiveMediaSource: MediaSourceChoice {
    automaticMediaSource || !mediaSource.isAvailable ? .system : mediaSource
  }

  /// Сдвиг выреза для окна острова. Значения из UserDefaults могли прийти руками: зажимаем в −2…2
  var notchTuning: NotchTuning {
    NotchTuning(width: min(max(notchWidthOffset, -2), 2), height: min(max(notchHeightOffset, -2), 2))
  }

  /// Последний вырез встроенного экрана: размер виртуального выреза, когда крышка закрыта.
  /// Служебное значение: onChange не зовёт
  var builtInNotch: CGSize? {
    get {
      let width = defaults.double(forKey: Key.builtInNotchWidth)
      let height = defaults.double(forKey: Key.builtInNotchHeight)
      return width > 0 && height > 0 ? CGSize(width: width, height: height) : nil
    }
    set {
      guard let newValue else {
        defaults.removeObject(forKey: Key.builtInNotchWidth)
        defaults.removeObject(forKey: Key.builtInNotchHeight)
        return
      }
      defaults.set(newValue.width, forKey: Key.builtInNotchWidth)
      defaults.set(newValue.height, forKey: Key.builtInNotchHeight)
    }
  }

  // swiftlint:disable:next function_body_length - чтение каждой настройки из UserDefaults, по строке на ключ
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    expandOnHover = defaults.object(forKey: Key.expandOnHover) as? Bool ?? true
    hoverDuration = defaults.object(forKey: Key.hoverDuration) as? Double ?? 0
    forceSimulatedNotch = defaults.bool(forKey: Key.forceSimulatedNotch)
    display = DisplayChoice(storageValue: defaults.string(forKey: Key.display))
    playSounds = defaults.object(forKey: Key.playSounds) as? Bool ?? true
    hideMenuBarIcon = defaults.bool(forKey: Key.hideMenuBarIcon)
    notchWidthOffset = defaults.double(forKey: Key.notchWidthOffset)
    notchHeightOffset = defaults.double(forKey: Key.notchHeightOffset)
    batteryEnabled = Self.read(defaults, Key.batteryEnabled, true)
    batteryDuration = Self.read(defaults, Key.batteryDuration, 5.0)
    notifyLowPower = Self.read(defaults, Key.notifyLowPower, true)
    warnLowBattery = Self.read(defaults, Key.warnLowBattery, true)
    lowBatteryThreshold = Self.read(defaults, Key.lowBatteryThreshold, 0.1)
    lowBatterySound = Self.read(defaults, Key.lowBatterySound, true)
    hideBatteryLabel = Self.read(defaults, Key.hideBatteryLabel, false)
    hideBatteryPercentage = Self.read(defaults, Key.hideBatteryPercentage, false)
    connectivityEnabled = Self.read(defaults, Key.connectivityEnabled, true)
    connectivityDuration = Self.read(defaults, Key.connectivityDuration, 5.0)
    warnHeadphonesLowBattery = Self.read(defaults, Key.warnHeadphonesLowBattery, true)
    headphonesLowBatteryThreshold = Self.read(defaults, Key.headphonesLowBatteryThreshold, 0.2)
    headphonesLowBatterySound = Self.read(defaults, Key.headphonesLowBatterySound, true)
    soundHUDEnabled = Self.read(defaults, Key.soundHUDEnabled, true)
    soundHUDDuration = Self.read(defaults, Key.soundHUDDuration, 1.5)
    soundHUDStyle = Self.readRaw(defaults, Key.soundHUDStyle, HUDBarStyle.decibel)
    soundHUDPercentage = Self.read(defaults, Key.soundHUDPercentage, false)
    soundHUDHideLabel = Self.read(defaults, Key.soundHUDHideLabel, false)
    soundHUDSpeed = Self.readRaw(defaults, Key.soundHUDSpeed, HUDSpeed.fast)
    soundHUDIcon = Self.readRaw(defaults, Key.soundHUDIcon, HUDIcon.device)
    displayHUDEnabled = Self.read(defaults, Key.displayHUDEnabled, true)
    displayHUDDuration = Self.read(defaults, Key.displayHUDDuration, 1.5)
    displayHUDStyle = Self.readRaw(defaults, Key.displayHUDStyle, HUDBarStyle.accent)
    displayHUDPercentage = Self.read(defaults, Key.displayHUDPercentage, false)
    displayHUDHideLabel = Self.read(defaults, Key.displayHUDHideLabel, false)
    displayHUDSpeed = Self.readRaw(defaults, Key.displayHUDSpeed, HUDSpeed.fast)
    nowPlayingEnabled = Self.read(defaults, Key.nowPlayingEnabled, true)
    idleDuration = Self.read(defaults, Key.idleDuration, 3.0)
    quickPeek = Self.read(defaults, Key.quickPeek, true)
    peekOnMediaChange = Self.read(defaults, Key.peekOnMediaChange, true)
    peekDuration = Self.read(defaults, Key.peekDuration, 2.0)
    hideWhileSourceActive = Self.read(defaults, Key.hideWhileSourceActive, false)
    waveformStyle = Self.readRaw(defaults, Key.waveformStyle, WaveformStyle.colored)
    disableCompactWaveform = Self.read(defaults, Key.disableCompactWaveform, false)
    disableArtworkFlip = Self.read(defaults, Key.disableArtworkFlip, false)
    hideTitleExtras = Self.read(defaults, Key.hideTitleExtras, false)
    automaticMediaSource = Self.read(defaults, Key.automaticMediaSource, true)
    mediaSource = Self.readRaw(defaults, Key.mediaSource, MediaSourceChoice.system)
    playerControl = Self.readRaw(defaults, Key.playerControl, PlayerExtraControl.shuffle)
    showRemainingTime = Self.read(defaults, Key.showRemainingTime, true)
    idleActivity = Self.readRaw(defaults, Key.idleActivity, IdleActivity.duo)
    mostRecentActivity = Self.read(defaults, Key.mostRecentActivity, false)
    forceEnableActivity = Self.read(defaults, Key.forceEnableActivity, true)
    swipeToDismiss = Self.read(defaults, Key.swipeToDismiss, true)
    naturalMovement = Self.read(defaults, Key.naturalMovement, true)
  }

  /// Запись настройки: одинаковое значение не пишется и не зовёт onChange
  private func save<T: Equatable>(_ old: T, _ new: T, _ key: String) {
    guard old != new else { return }
    defaults.set(new, forKey: key)
    onChange()
  }

  nonisolated private static func read<T>(_ defaults: UserDefaults, _ key: String, _ fallback: T) -> T {
    defaults.object(forKey: key) as? T ?? fallback
  }

  /// Перечисления пишутся rawValue: отдельное имя, чтобы не спорить с save<T: Equatable> при разрешении перегрузки
  private func saveRaw<T: RawRepresentable & Equatable>(_ old: T, _ new: T, _ key: String) where T.RawValue == String {
    guard old != new else { return }
    defaults.set(new.rawValue, forKey: key)
    onChange()
  }

  /// nonisolated: T.init(rawValue:) не привязан к MainActor, а Swift 6 иначе считает передачу через границу гонкой
  nonisolated private static func readRaw<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String, _ fallback: T) -> T
  where T.RawValue == String {
    defaults.string(forKey: key).flatMap(T.init(rawValue:)) ?? fallback
  }

  var powerRules: PowerRules {
    PowerRules(
      isEnabled: batteryEnabled, notifiesLowPower: notifyLowPower, warnsLowBattery: warnLowBattery,
      lowBatteryThreshold: lowBatteryThreshold)
  }

  var alertRules: AlertRules {
    var rules = AlertRules()
    rules.batteryDuration = .seconds(batteryDuration)
    rules.lowBatterySound = lowBatterySound
    rules.connectivityDuration = .seconds(connectivityDuration)
    rules.headphonesLowBatterySound = headphonesLowBatterySound
    return rules
  }

  var appearance: IslandAppearance {
    var appearance = IslandAppearance()
    appearance.battery = BatteryAlertStyle(hidesLabel: hideBatteryLabel, hidesPercentage: hideBatteryPercentage)
    appearance.volumeHUD = HUDAppearance(
      style: soundHUDStyle, showsPercentage: soundHUDPercentage, hidesLabel: soundHUDHideLabel,
      speed: soundHUDSpeed, icon: soundHUDIcon)
    appearance.brightnessHUD = HUDAppearance(
      style: displayHUDStyle, showsPercentage: displayHUDPercentage, hidesLabel: displayHUDHideLabel,
      speed: displayHUDSpeed)
    appearance.waveform = waveformStyle
    appearance.compactWaveform = !disableCompactWaveform
    appearance.artworkFlip = !disableArtworkFlip
    appearance.hidesTitleExtras = hideTitleExtras
    appearance.playerControl = playerControl
    appearance.showsRemainingTime = showRemainingTime
    return appearance
  }

  func machineConfig(from base: IslandMachine.Config) -> IslandMachine.Config {
    var config = base.applying(expandOnHover: expandOnHover, hoverDuration: hoverDuration)
    config.alerts = alertRules
    config.hudDurations.volume = .seconds(soundHUDDuration)
    config.hudDurations.brightness = .seconds(displayHUDDuration)
    var nowPlaying = NowPlayingRules()
    nowPlaying.isEnabled = nowPlayingEnabled
    nowPlaying.idleDelay = .seconds(idleDuration)
    nowPlaying.quickPeek = quickPeek
    nowPlaying.peeksOnPlayback = peekOnMediaChange
    nowPlaying.peekDuration = .seconds(peekDuration)
    nowPlaying.hidesWhileSourceActive = hideWhileSourceActive
    config.nowPlaying = nowPlaying
    var expanded = ExpandedRules()
    expanded.idleActivity = idleActivity
    expanded.mostRecent = mostRecentActivity
    expanded.forceEnable = forceEnableActivity
    config.expanded = expanded
    return config
  }
}
