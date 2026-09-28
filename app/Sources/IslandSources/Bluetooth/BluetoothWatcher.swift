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

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let name = device.name, AirPodsBattery.isHeadphones(name: name) else { return }
        log.info("headphones connected \(name, privacy: .public)")
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            let battery = await AirPodsBattery.read(name: name)
            self?.onConnect(AirPodsInfo(name: name, battery: battery))
        }
    }
}
