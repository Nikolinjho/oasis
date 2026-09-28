/// Уведомление: держится duration и уходит. Живёт в строке menu bar и растёт в ширину.
/// Приходит во время HUD или другого уведомления — ждёт в очереди IslandModel.alertQueue
public enum IslandAlert: Equatable, Sendable {
    /// Питание подключено: уровень заряда 0…1
    case charging(level: Double)
    /// Заряд опустился до порога без питания (Warn on low battery, порог 10%)
    case lowBattery(level: Double)
    /// Включился режим энергосбережения (Notify on low power mode). Уровень — для батарейки
    case lowPower(level: Double)
    /// Напоминание о событии за minutes минут (решение 27.09: за 15 и за 5)
    case calendarReminder(CalendarReminder)

    /// Вид: повтор того же вида в очереди заменяет ждущее, а поверх показанного обновляет его
    public enum Kind: Hashable, Sendable {
        case charging, lowBattery, lowPower
        case calendarReminder
    }

    public var kind: Kind {
        switch self {
        case .charging: .charging
        case .lowBattery: .lowBattery
        case .lowPower: .lowPower
        case .calendarReminder: .calendarReminder
        }
    }

    /// Кто вперёд в очереди. У Alcove приоритеты неизвестны: значения — допущение плана P1
    public var priority: Int {
        switch self {
        case .lowBattery, .calendarReminder: 2
        case .lowPower: 1
        case .charging: 0
        }
    }

    /// Duration страницы Battery по умолчанию — 5 с (ui-inspection 1.3)
    public var duration: Duration {
        switch self {
        case .charging, .lowBattery, .lowPower: IslandTiming.alertVisible
        // как peek календаря на старте: Peek duration 4 с (ui-inspection 3.5)
        case .calendarReminder: IslandTiming.calendarPeek
        }
    }

    /// Звуки Alcove по умолчанию: Play sound on low battery вкл (ui-inspection 1.3), low power — low-power.caf из бандла
    public var sound: IslandSound? {
        switch self {
        case .charging: nil
        case .lowBattery: .lowBattery
        case .lowPower: .lowPower
        // допущение плана P1: звук события и на напоминаниях, не только на старте
        case .calendarReminder: .event
        }
    }
}

/// Звуки из бандла Alcove (assets/sounds). rawValue — имя файла без расширения
public enum IslandSound: String, Sendable, CaseIterable {
    case event
    case lowBattery = "low-battery"
    case lowPower = "low-power"
}

/// Что показывает напоминание: название, сколько минут до начала, цвет календаря
public struct CalendarReminder: Equatable, Sendable {
    public var title: String
    public var minutes: Int
    public var color: RGB

    public init(title: String, minutes: Int, color: RGB) {
        self.title = title
        self.minutes = minutes
        self.color = color
    }
}
