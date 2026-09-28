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

    public init(style: HUDBarStyle, showsPercentage: Bool = false, hidesLabel: Bool = false, speed: HUDSpeed = .fast,
                icon: HUDIcon = .symbol) {
        self.style = style
        self.showsPercentage = showsPercentage
        self.hidesLabel = hidesLabel
        self.speed = speed
        self.icon = icon
    }
}

/// Как остров рисует свои поверхности: настройки страниц, которые меняют вид, а не поведение.
/// Поведение живёт в IslandMachine.Config. Store держит значение и отдаёт его в IslandView и геометрию
public struct IslandAppearance: Equatable, Sendable {
    public var battery = BatteryAlertStyle()
    /// Sound: по умолчанию Decibel и Show device (ui-inspection 1.7)
    public var volumeHUD = HUDAppearance(style: .decibel, icon: .device)
    /// Display: по умолчанию Accent (ui-inspection 1.6)
    public var brightnessHUD = HUDAppearance(style: .accent)

    public init() {}

    public func hud(_ kind: HUDKind) -> HUDAppearance {
        kind == .volume ? volumeHUD : brightnessHUD
    }

    public static let `default` = IslandAppearance()
}
