import Foundation
import IslandCore

/// Опрос заряда подключённых наушников (Connectivity → Warn on low battery). system_profiler не шлёт изменений:
/// раз в минуту, и только пока в CoreAudio есть Bluetooth-выход — без наушников опрос ничего не стоит
@MainActor
public final class HeadphonesBatteryMonitor {
    public var onReading: ([AirPodsInfo]) -> Void = { _ in }
    private var task: Task<Void, Never>?
    /// Период опроса. Решение пользователя 28.09
    static let interval: Duration = .seconds(60)

    public init() {}

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                guard !Task.isCancelled, !BluetoothAudioOutputs.current().isEmpty else { continue }
                guard let json = await AirPodsBattery.readProfile() else { continue }
                self?.onReading(AirPodsBattery.connectedHeadphones(json: json))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
