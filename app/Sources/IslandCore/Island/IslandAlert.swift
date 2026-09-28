/// Уведомление: держится alertVisible и уходит. Как HUD, живёт в строке menu bar высотой 32 и растёт в ширину.
/// P1 добавляет сюда Low Battery, Low Power, AirPods и напоминания календаря
public enum IslandAlert: Equatable, Sendable {
    /// Питание подключено: уровень заряда 0…1
    case charging(level: Double)
}
