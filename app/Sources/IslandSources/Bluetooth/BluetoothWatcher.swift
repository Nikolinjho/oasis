import CoreAudio
import Foundation
import IOBluetooth
import IslandCore

/// Подключения Bluetooth-наушников. Через 2 с после подключения читает заряд и сообщает:
/// у Alcove уведомление приходит примерно через 2 с (ui-inspection 3.6). Отключение уведомления не даёт.
/// Подключение — и уведомление IOBluetooth, и появление Bluetooth-выхода в CoreAudio (наушники достали из кейса)
@MainActor
public final class BluetoothWatcher: NSObject {
    public var onConnect: (AirPodsInfo) -> Void = { _ in }
    private var registration: IOBluetoothUserNotification?
    /// Адреса устройств, подключённых до start(): регистрация сразу присылает по ним connected,
    /// а это не новое подключение — первое такое уведомление пропускаем
    private var connectedAtStart: Set<String> = []
    /// Ждущие чтения подключения (имя и адрес) → уже был повтор (AirPodsBattery.resolve)
    private var pending: [AirPodsBattery.Connection: Bool] = [:]
    /// Окно пачки: после выхода из сна переподключаются сразу несколько устройств, а system_profiler
    /// запускается один раз на окно и разбирается для всех подключений
    private var batch: Task<Void, Never>?
    private var startupGrace: Task<Void, Never>?
    private var outputs = BluetoothAudioOutputs.Tracker()
    private var onDevicesChanged: AudioObjectPropertyListenerBlock?
    private let log = SourceLog.logger("bluetooth")

    /// Окно пачки и задержка уведомления: ~2 с, как у Alcove (ui-inspection 3.6)
    static let window: Duration = .seconds(2)
    /// Сколько ждать уведомлений по уже подключённым устройствам после регистрации. Замера нет, оценка:
    /// IOBluetooth присылает их сразу, но не обязательно синхронно внутри register
    static let startupGraceTime: Duration = .seconds(5)

    public func start() {
        guard registration == nil else { return }
        let devices = IOBluetoothDevice.pairedDevices()?.compactMap { $0 as? IOBluetoothDevice } ?? []
        connectedAtStart = Set(devices.filter { $0.isConnected() }.compactMap(\.addressString))
        registration = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        if registration == nil { log.error("bluetooth connect notifications unavailable") }
        startOutputs()
        // не пришло уведомление по подключённому до старта — адрес не должен глушить его следующее подключение
        startupGrace = Task { [weak self] in
            try? await Task.sleep(for: Self.startupGraceTime)
            if !Task.isCancelled { self?.connectedAtStart = [] }
        }
    }

    public func stop() {
        registration?.unregister()
        registration = nil
        batch?.cancel()
        batch = nil
        startupGrace?.cancel()
        startupGrace = nil
        pending = [:]
        connectedAtStart = []
        if let onDevicesChanged {
            var address = BluetoothAudioOutputs.devicesAddress
            AudioObjectRemovePropertyListenerBlock(BluetoothAudioOutputs.system, &address, .main, onDevicesChanged)
        }
        onDevicesChanged = nil
        outputs = BluetoothAudioOutputs.Tracker()
    }

    /// Первый снимок выходов — исходный; дальше каждый появившийся Bluetooth-выход идёт в ту же пачку.
    /// При обычном подключении он приходит вместе с уведомлением IOBluetooth, resolve оставит одно по адресу
    private func startOutputs() {
        _ = outputs.update(BluetoothAudioOutputs.current())
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.outputsChanged() }
        }
        var address = BluetoothAudioOutputs.devicesAddress
        guard AudioObjectAddPropertyListenerBlock(BluetoothAudioOutputs.system, &address, .main, block) == noErr else {
            log.error("audio device list notifications unavailable")
            return
        }
        onDevicesChanged = block
    }

    private func outputsChanged() {
        for connection in outputs.update(BluetoothAudioOutputs.current()) {
            log.info("bluetooth output appeared \(connection.name, privacy: .public)")
            enqueue(connection)
        }
    }

    /// IOBluetooth шлёт уведомление с фоновой очереди CoreBluetooth, а не с главного потока (краш 28.09 в проверке
    /// изоляции MainActor). Здесь только адрес и имя, остальное — на главном
    @objc nonisolated private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString
        let name = device.name
        Task { @MainActor [weak self] in self?.connected(address: address, name: name) }
    }

    private func connected(address: String?, name: String?) {
        if let address, connectedAtStart.remove(address) != nil { return }
        guard let name else { return }
        enqueue(AirPodsBattery.Connection(name: name, address: address))
    }

    private func enqueue(_ connection: AirPodsBattery.Connection) {
        if pending[connection] == nil { pending[connection] = false }
        guard batch == nil else { return }
        batch = Task { [weak self] in await self?.drain() }
    }

    /// Окно за окном, пока есть ждущие подключения: повтор без заряда тоже ждёт следующего окна.
    /// После отмены (stop) ничего не трогает: batch к этому времени уже чужой или nil
    private func drain() async {
        while !pending.isEmpty {
            try? await Task.sleep(for: Self.window)
            if Task.isCancelled { return }
            let connections = pending
            pending = [:]
            let json = await AirPodsBattery.readProfile()
            if Task.isCancelled { return }
            let result = AirPodsBattery.resolve(connections, json: json)
            for connection in result.retry where pending[connection] == nil { pending[connection] = true }
            for info in result.show {
                log.info("headphones connected \(info.name, privacy: .public)")
                onConnect(info)
            }
        }
        batch = nil
    }
}
