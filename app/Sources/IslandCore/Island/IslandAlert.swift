/// Уведомление: держится duration и уходит. Живёт в строке menu bar и растёт в ширину.
/// Приходит во время HUD или другого уведомления — ждёт в очереди IslandModel.alertQueue
public enum IslandAlert: Equatable, Sendable {
    /// Питание подключено: уровень заряда 0…1
    case charging(level: Double)
    /// Заряд опустился до порога без питания (Warn on low battery, порог 10%)
    case lowBattery(level: Double)
    /// Включился режим энергосбережения (Notify on low power mode). Уровень — для батарейки
    case lowPower(level: Double)

    /// Вид: повтор того же вида в очереди заменяет ждущее, а поверх показанного обновляет его
    public enum Kind: Hashable, Sendable {
        case charging, lowBattery, lowPower
    }

    public var kind: Kind {
        switch self {
        case .charging: .charging
        case .lowBattery: .lowBattery
        case .lowPower: .lowPower
        }
    }

    /// Кто вперёд в очереди. У Alcove приоритеты неизвестны: значения — допущение плана P1
    public var priority: Int {
        switch self {
        case .lowBattery: 2
        case .lowPower: 1
        case .charging: 0
        }
    }

    /// Duration страницы Battery по умолчанию — 5 с (ui-inspection 1.3)
    public var duration: Duration {
        switch self {
        case .charging, .lowBattery, .lowPower: IslandTiming.alertVisible
        }
    }

    /// Звуки Alcove по умолчанию: Play sound on low battery вкл (ui-inspection 1.3), low power — low-power.caf из бандла
    public var sound: IslandSound? {
        switch self {
        case .charging: nil
        case .lowBattery: .lowBattery
        case .lowPower: .lowPower
        }
    }
}

/// Звуки из бандла Alcove (assets/sounds). rawValue — имя файла без расширения
public enum IslandSound: String, Sendable, CaseIterable {
    case event
    case lowBattery = "low-battery"
    case lowPower = "low-power"
}
