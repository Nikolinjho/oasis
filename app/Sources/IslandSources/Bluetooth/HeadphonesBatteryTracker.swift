/// Пересечение порога низкого заряда наушников. Помнит последний уровень по адресу:
/// предупреждение — один раз при переходе через порог сверху, снова — только после подъёма выше порога
public struct HeadphonesBatteryTracker: Sendable {
  private var last: [String: Double] = [:]

  public init() {}

  /// Подключение: запомнить уровень. true — уже ниже порога, уведомление о подключении идёт с красным кольцом
  public mutating func connected(address: String, level: Double?, threshold: Double) -> Bool {
    guard let level else { return false }
    last[AirPodsBattery.normalized(address: address)] = level
    return level <= threshold
  }

  /// Опрос раз в минуту. true — порог пересечён сверху. Первое чтение адреса только запоминается:
  /// о подключении до запуска приложения ничего не известно
  public mutating func update(address: String, level: Double, threshold: Double) -> Bool {
    let key = AirPodsBattery.normalized(address: address)
    defer { last[key] = level }
    guard let previous = last[key] else { return false }
    return previous > threshold && level <= threshold
  }
}
