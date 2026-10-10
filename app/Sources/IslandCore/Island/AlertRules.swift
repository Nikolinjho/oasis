/// Длительность и звук уведомления по настройкам страниц Battery и Connectivity (ui-inspection 1.3, 1.4).
/// Вид уведомления (IslandAlert.duration, .sound) — значения Alcove по умолчанию, здесь — то, что выбрал пользователь
public struct AlertRules: Equatable, Sendable {
  /// Battery → Duration, 2.5…6 с
  public var batteryDuration: Duration = IslandTiming.alertVisible
  /// Connectivity → Duration, 2.5…6 с
  public var connectivityDuration: Duration = IslandTiming.alertVisible
  /// Battery → Play sound on low battery
  public var lowBatterySound = true
  /// Connectivity → Play sound on low battery: звук низкого заряда наушников (Task 5)
  public var headphonesLowBatterySound = true
  /// Calendar: Peek duration и звук напоминания Before event starts. Config.calendar смотрит сюда же
  public var calendar = CalendarRules()

  public init() {}

  public func duration(for alert: IslandAlert) -> Duration {
    switch alert {
    case .charging, .lowBattery, .lowPower: batteryDuration
    case .airpods: connectivityDuration
    case .calendarReminder: calendar.peekDuration
    case .claude, .soon: alert.duration
    }
  }

  public func sound(for alert: IslandAlert) -> IslandSound? {
    switch alert {
    case .lowBattery: lowBatterySound ? alert.sound : nil
    case .airpods: headphonesLowBatterySound ? alert.sound : nil
    case .calendarReminder: calendar.sound ? alert.sound : nil
    case .charging, .lowPower: alert.sound
    case .claude, .soon: alert.sound
    }
  }
}
