import Foundation
import IOBluetooth
import IslandCore

/// Подключения Bluetooth-наушников. Через 2 с после подключения читает заряд и сообщает:
/// у Alcove уведомление приходит примерно через 2 с (ui-inspection 3.6). Отключение уведомления не даёт
@MainActor
public final class BluetoothWatcher: NSObject {
    public var onConnect: (AirPodsInfo) -> Void = { _ in }
    private var registration: IOBluetoothUserNotification?
    private let log = SourceLog.logger("bluetooth")

    public func start() {
        registration = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        if registration == nil { log.error("bluetooth connect notifications unavailable") }
    }

    public func stop() {
        registration?.unregister()
        registration = nil
    }

    /// Переименованные наушники по имени не узнать: system_profiler читается для любого подключения,
    /// а наушники ли это, решает AirPodsBattery.info по имени или vendorID и minorType
    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let name = device.name else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            let found = await AirPodsBattery.read(name: name)
            guard let self, let info = AirPodsBattery.info(name: name, device: found) else { return }
            log.info("headphones connected \(name, privacy: .public)")
            onConnect(info)
        }
    }
}
