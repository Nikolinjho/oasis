import Foundation
import IslandCore

/// Опрос заряда подключённых наушников (Connectivity → Warn on low battery). system_profiler не шлёт изменений:
/// раз в минуту, и только пока включены Connectivity и Warn on low battery (shouldPoll) и в CoreAudio есть
/// Bluetooth-выход — без них опрос system_profiler ничего не стоит
@MainActor
public final class HeadphonesBatteryMonitor {
  public var onReading: ([AirPodsInfo]) -> Void = { _ in }
  /// Connectivity → главный тумблер и Warn on low battery. Проверяется на каждой итерации: настройки
  /// могут поменяться, пока монитор уже запущен. По умолчанию true — для тестов и мест без настроек
  public var shouldPoll: () -> Bool = { true }
  private var task: Task<Void, Never>?
  /// Период опроса. Решение пользователя 28.09
  static let interval: Duration = .seconds(60)

  public init() {}

  public func start() {
    guard task == nil else { return }
    task = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.interval)
        // монитор освободили во время сна — дальше опрашивать некого
        guard let self, !Task.isCancelled else { return }
        guard self.shouldPoll(), !BluetoothAudioOutputs.current().isEmpty else { continue }
        guard let json = await AirPodsBattery.readProfile() else { continue }
        self.onReading(AirPodsBattery.connectedHeadphones(json: json))
      }
    }
  }

  public func stop() {
    task?.cancel()
    task = nil
  }
}
