import Foundation
import IslandCore
import os

/// Заряд и модель Bluetooth-наушников из system_profiler: публичного API для AirPods нет
public enum AirPodsBattery {
    /// Подключённое устройство из вывода system_profiler
    public struct Device: Equatable, Sendable {
        public var battery: Double?
        /// Наушники Apple (AirPods, Beats): device_vendorID 0x004C и device_minorType Headphones.
        /// Ловит переименованные наушники, у которых имя модель не выдаёт
        public var isAppleHeadphones: Bool
        public var model: AirPodsInfo.Model?
    }

    public static func isHeadphones(name: String) -> Bool {
        name.localizedCaseInsensitiveContains("AirPods") || name.localizedCaseInsensitiveContains("Beats")
    }

    /// Наушники по имени или, для переименованных, по данным system_profiler
    public static func isHeadphones(name: String, device: Device?) -> Bool {
        isHeadphones(name: name) || device?.isAppleHeadphones == true
    }

    /// Сведения для уведомления или nil, если это не наушники
    public static func info(name: String, device: Device?) -> AirPodsInfo? {
        guard isHeadphones(name: name, device: device) else { return nil }
        return AirPodsInfo(name: name, battery: device?.battery, model: device?.model)
    }

    /// Подключённое устройство по имени. Ключи сверены с живым выводом macOS 26: device_connected /
    /// device_not_connected, заряд device_batteryLevelLeft/Right/Case строками «82%», device_vendorID «0x004C»,
    /// device_minorType «Headphones», device_productID «0x2014». Без подключённых device_connected нет вовсе
    public static func device(json: Data, name: String) -> Device? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        for controller in controllers {
            for entry in controller["device_connected"] as? [[String: Any]] ?? [] {
                guard let device = entry[name] as? [String: Any] else { continue }
                let vendor = (device["device_vendorID"] as? String)?.lowercased()
                let minor = device["device_minorType"] as? String
                return Device(
                    battery: battery(device),
                    isAppleHeadphones: vendor == "0x004c" && minor == "Headphones",
                    model: model(productID: device["device_productID"] as? String))
            }
        }
        return nil
    }

    /// Меньший из наушников, иначе Main (у Max один аккумулятор)
    static func battery(_ device: [String: Any]) -> Double? {
        let buds = ["device_batteryLevelLeft", "device_batteryLevelRight"].compactMap { percent(device[$0]) }
        if let lowest = buds.min() { return lowest }
        return percent(device["device_batteryLevelMain"])
    }

    /// Только productID, в которых уверены. 0x2014 подтверждён живым выводом («…AirPods Pro»), остальные —
    /// общеизвестные ID Apple: 0x200E AirPods Pro, 0x2024 AirPods Pro 2 USB-C, 0x200A AirPods Max.
    /// Прочие (в том числе обычные AirPods и Beats) — nil: глиф по имени, для переименованных — airpods
    static func model(productID: String?) -> AirPodsInfo.Model? {
        switch productID?.lowercased() {
        case "0x200e", "0x2014", "0x2024": .pro
        case "0x200a": .max
        default: nil
        }
    }

    /// «82%», «85 %» → 0.82, 0.85. Вне 0…100 зажимается
    static func percent(_ value: Any?) -> Double? {
        guard let text = value as? String,
              let number = Double(text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
        else { return nil }
        return min(max(number / 100, 0), 1)
    }

    /// Разбор пачки подключений по одному выводу system_profiler. names — имя → уже был повтор.
    /// Наушники без заряда (system_profiler ещё не успел его узнать) и все имена при сбое чтения (json nil)
    /// идут на один повтор в следующем окне; после повтора наушники показываются как есть, без заряда
    static func resolve(_ names: [String: Bool], json: Data?) -> (show: [AirPodsInfo], retry: [String]) {
        var show: [AirPodsInfo] = []
        var retry: [String] = []
        for (name, retried) in names.sorted(by: { $0.key < $1.key }) {
            let info = info(name: name, device: json.flatMap { device(json: $0, name: name) })
            if !retried, info?.battery == nil, info != nil || json == nil {
                retry.append(name)
            } else if let info {
                show.append(info)
            }
        }
        return (show, retry)
    }

    /// Вывод `system_profiler SPBluetoothDataType -json`, nil при сбое или таймауте
    static func readProfile() async -> Data? {
        await output(of: URL(fileURLWithPath: "/usr/sbin/system_profiler"), arguments: ["SPBluetoothDataType", "-json"], timeout: 5)
    }

    /// stdout процесса без блокировки пула задач: конец — terminationHandler, pipe читается на своей очереди
    /// (иначе полный буфер pipe держит процесс). Ненулевой код — nil. Не уложился в timeout — сразу nil,
    /// затем terminate, а через killGrace SIGKILL, если процесс глушит SIGTERM. Результат отдаётся один раз
    /// (finish): процесс или его потомок, держащий stdout, не может подвесить вызывающего
    static func output(of executable: URL, arguments: [String], timeout: TimeInterval, killGrace: TimeInterval = 1) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let finished = OSAllocatedUnfairLock(initialState: false)
            @Sendable func finish(_ data: Data?) {
                let first = finished.withLock { done in
                    defer { done = true }
                    return !done
                }
                if first { continuation.resume(returning: data) }
            }
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            let output = OSAllocatedUnfairLock(initialState: Data())
            let reading = DispatchGroup()
            process.terminationHandler = { process in
                let status = process.terminationStatus
                reading.notify(queue: .global()) {
                    finish(status == 0 ? output.withLock { $0 } : nil)
                }
            }
            // enter до run: быстрый процесс может закончиться раньше, чем стартует чтение,
            // и notify без него отдал бы пустые данные
            reading.enter()
            do {
                try process.run()
            } catch {
                reading.leave()
                finish(nil)
                return
            }
            // читать только после запуска: иначе при сбое run() чтение ждало бы EOF вечно
            DispatchQueue.global().async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                output.withLock { $0 = data }
                reading.leave()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                finish(nil)
                process.terminate()
                let pid = process.processIdentifier
                DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
                    if process.isRunning { kill(pid, SIGKILL) }
                }
            }
        }
    }
}
