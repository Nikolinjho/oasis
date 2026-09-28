/// Питание встроенной батареи
public struct PowerState: Equatable, Sendable {
    public var isPluggedIn: Bool
    public var isCharging: Bool
    /// Заряд 0…1
    public var level: Double
    public var isLowPowerMode: Bool

    public init(isPluggedIn: Bool, isCharging: Bool, level: Double, isLowPowerMode: Bool) {
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.level = level
        self.isLowPowerMode = isLowPowerMode
    }
}

/// Какие уведомления даёт смена состояния питания. P1 добавляет Low Battery и Low Power
public enum PowerNotices {
    /// Первое состояние после запуска ничего не показывает: иначе Charging всплывал бы на каждом старте
    public static func alerts(from old: PowerState?, to new: PowerState) -> [IslandAlert] {
        guard let old else { return [] }
        var alerts: [IslandAlert] = []
        // Charging — по подключению питания, а не по флагу зарядки: на 100% от сети isCharging ложен
        if new.isPluggedIn, !old.isPluggedIn { alerts.append(.charging(level: new.level)) }
        return alerts
    }
}
