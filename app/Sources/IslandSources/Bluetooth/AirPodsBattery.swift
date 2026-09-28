import Foundation
import IslandCore

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

    /// Вывод `system_profiler SPBluetoothDataType -json` → заряд 0…1 подключённого устройства по имени
    public static func parse(json: Data, name: String) -> Double? {
        device(json: json, name: name)?.battery
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

    /// «82%» → 0.82
    static func percent(_ value: Any?) -> Double? {
        guard let text = value as? String, let number = Double(text.replacingOccurrences(of: "%", with: "")) else { return nil }
        return number / 100
    }

    /// system_profiler работает 1–2 с: вне главного потока
    public static func read(name: String) async -> Device? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return device(json: data, name: name)
        }.value
    }
}
