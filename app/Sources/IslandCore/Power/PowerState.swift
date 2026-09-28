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

/// Battery (ui-inspection 1.3): главный тумблер, Notify on low power mode, Warn on low battery, Low battery threshold
public struct PowerRules: Equatable, Sendable {
    /// Главный тумблер страницы: гасит Charging, Low Battery и Low Power (решение 28.09)
    public var isEnabled: Bool
    public var notifiesLowPower: Bool
    public var warnsLowBattery: Bool
    /// 0.1, 0.2 или 0.3
    public var lowBatteryThreshold: Double

    public init(isEnabled: Bool = true, notifiesLowPower: Bool = true, warnsLowBattery: Bool = true,
                lowBatteryThreshold: Double = PowerNotices.lowBatteryThreshold) {
        self.isEnabled = isEnabled
        self.notifiesLowPower = notifiesLowPower
        self.warnsLowBattery = warnsLowBattery
        self.lowBatteryThreshold = lowBatteryThreshold
    }
}

/// Какие уведомления даёт смена состояния питания
public enum PowerNotices {
    /// Low battery threshold по умолчанию — 10% (ui-inspection 1.3)
    public static let lowBatteryThreshold = 0.10

    /// Первое состояние после запуска ничего не показывает: иначе Charging всплывал бы на каждом старте
    public static func alerts(from old: PowerState?, to new: PowerState, rules: PowerRules = PowerRules()) -> [IslandAlert] {
        guard let old, rules.isEnabled else { return [] }
        var alerts: [IslandAlert] = []
        // Charging — по подключению питания, а не по флагу зарядки: на 100% от сети isCharging ложен
        if new.isPluggedIn, !old.isPluggedIn { alerts.append(.charging(level: new.level)) }
        let threshold = rules.lowBatteryThreshold
        if rules.warnsLowBattery, !new.isPluggedIn, new.level <= threshold, old.level > threshold {
            alerts.append(.lowBattery(level: new.level))
        }
        if rules.notifiesLowPower, new.isLowPowerMode, !old.isLowPowerMode { alerts.append(.lowPower(level: new.level)) }
        // несколько уведомлений сразу — по приоритету очереди (Low Battery выше Low Power выше Charging)
        return alerts.sorted { $0.priority > $1.priority }
    }
}
