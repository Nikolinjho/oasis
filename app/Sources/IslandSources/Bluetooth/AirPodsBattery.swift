import Foundation

/// Заряд Bluetooth-наушников из system_profiler: публичного API для AirPods нет
public enum AirPodsBattery {
    public static func isHeadphones(name: String) -> Bool {
        name.localizedCaseInsensitiveContains("AirPods") || name.localizedCaseInsensitiveContains("Beats")
    }

    /// Вывод `system_profiler SPBluetoothDataType -json` → заряд 0…1 подключённого устройства по имени.
    /// Ключи сверены с живым выводом macOS 26: device_connected / device_not_connected, заряд
    /// device_batteryLevelLeft/Right/Case строками «82%». Без подключённых устройств device_connected нет вовсе
    public static func parse(json: Data, name: String) -> Double? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        for controller in controllers {
            for entry in controller["device_connected"] as? [[String: Any]] ?? [] {
                guard let device = entry[name] as? [String: Any] else { continue }
                let buds = ["device_batteryLevelLeft", "device_batteryLevelRight"].compactMap { percent(device[$0]) }
                if let lowest = buds.min() { return lowest }
                return percent(device["device_batteryLevelMain"])
            }
        }
        return nil
    }

    /// «82%» → 0.82
    static func percent(_ value: Any?) -> Double? {
        guard let text = value as? String, let number = Double(text.replacingOccurrences(of: "%", with: "")) else { return nil }
        return number / 100
    }

    /// system_profiler работает 1–2 с: вне главного потока
    public static func read(name: String) async -> Double? {
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
            return parse(json: data, name: name)
        }.value
    }
}
