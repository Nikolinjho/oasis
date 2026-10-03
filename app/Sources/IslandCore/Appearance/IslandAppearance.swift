/// Battery → Hide label, Hide percentage (ui-inspection 1.3)
public struct BatteryAlertStyle: Equatable, Sendable {
  public var hidesLabel: Bool
  /// Только у Low Battery: у Charging и Low Power процента нет (решение 28.09)
  public var hidesPercentage: Bool

  public init(hidesLabel: Bool = false, hidesPercentage: Bool = false) {
    self.hidesLabel = hidesLabel
    self.hidesPercentage = hidesPercentage
  }
}

/// Стиль полоски HUD (Display / Sound → плитки, ui-inspection 1.6, 1.7). У громкости White / Accent / Decibel,
/// у яркости White / Accent / Glow. В defaults Alcove Decibel называется stylized
public enum HUDBarStyle: String, CaseIterable, Sendable {
  case white, accent, decibel, glow

  /// Цвета Decibel. Оранжевый #E4916A и трек #563727 — ui-inspection 3.1 (HUD громкости, запись №1).
  /// Зелёный — AlcoveGreenColor из палитры бандла. Пороги 60% и 85% и красный — замера нет, оценка (решение 28.09)
  public static let decibelGreen = RGB(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255)
  public static let decibelOrange = RGB(red: 0xE4 / 255, green: 0x91 / 255, blue: 0x6A / 255)
  public static let decibelRed = RGB(red: 1, green: 69 / 255, blue: 58 / 255)
  public static let decibelTrack = RGB(red: 0x56 / 255, green: 0x37 / 255, blue: 0x27 / 255)

  public static func decibelColor(level: Double) -> RGB {
    level < 0.6 ? decibelGreen : level < 0.85 ? decibelOrange : decibelRed
  }
}

/// Скорость полоски HUD: tortoise / hare / bolt в плитках Alcove. Замера нет: Fast — наша прежняя .smooth(0.2)
public enum HUDSpeed: String, CaseIterable, Sendable {
  case smooth, fast, instant
}

/// Sound → Show symbol / Show device: уровень громкости или глиф устройства вывода
public enum HUDIcon: String, CaseIterable, Sendable {
  case symbol, device
}

public struct HUDAppearance: Equatable, Sendable {
  public var style: HUDBarStyle
  public var showsPercentage: Bool
  public var hidesLabel: Bool
  public var speed: HUDSpeed
  public var icon: HUDIcon

  public init(
    style: HUDBarStyle, showsPercentage: Bool = false, hidesLabel: Bool = false, speed: HUDSpeed = .fast,
    icon: HUDIcon = .symbol
  ) {
    self.style = style
    self.showsPercentage = showsPercentage
    self.hidesLabel = hidesLabel
    self.speed = speed
    self.icon = icon
  }
}

/// Now Playing → цвет волны (ui-inspection 1.8). Artwork в строках Alcove есть, в окне настроек — нет: не делаем
public enum WaveformStyle: String, CaseIterable, Sendable {
  case monochrome, colored, gradient
}

/// Как остров рисует свои поверхности: настройки страниц, которые меняют вид, а не поведение.
/// Поведение живёт в IslandMachine.Config. Store держит значение и отдаёт его в IslandView и геометрию
public struct IslandAppearance: Equatable, Sendable {
  public var battery = BatteryAlertStyle()
  /// Sound: по умолчанию Decibel и Show device (ui-inspection 1.7)
  public var volumeHUD = HUDAppearance(style: .decibel, icon: .device)
  /// Display: по умолчанию Accent (ui-inspection 1.6)
  public var brightnessHUD = HUDAppearance(style: .accent)
  /// Текущий выход: глиф для Show device в HUD громкости (VolumeControl.outputs)
  public var output = OutputDeviceKind.speakers
  /// Now Playing: по умолчанию Colored (progressStyle = color у Alcove)
  public var waveform = WaveformStyle.colored
  /// false — Disable compact waveform
  public var compactWaveform = true
  /// false — Disable artwork flip
  public var artworkFlip = true
  /// Hide media title extras
  public var hidesTitleExtras = false
  /// Now Playing → доп. кнопка плеера
  public var playerControl = PlayerExtraControl.shuffle
  /// Справа от прогресса: «-m:ss» до конца или длительность целиком (showRemainingTime = 1 у Alcove по умолчанию)
  public var showsRemainingTime = true
  /// Calendar: цвет компакта, полоска peek, сетка месяца
  public var calendar = CalendarAppearance()

  public init() {}

  public func hud(_ kind: HUDKind) -> HUDAppearance {
    kind == .volume ? volumeHUD : brightnessHUD
  }

  /// Hide media title extras: только показанный текст. NowPlayingInfo (и его trackKey) не трогаем —
  /// иначе ArtworkFlip увидел бы «новый трек» при каждом переключении настройки (ревью Task 9, 29.09)
  public func title(for info: NowPlayingInfo?) -> String? {
    guard let info else { return nil }
    return hidesTitleExtras ? TitleCleaner.clean(info.title) : info.title
  }

  public static let `default` = IslandAppearance()
}
