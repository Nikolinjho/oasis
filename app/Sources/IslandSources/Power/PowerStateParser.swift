import IOKit.ps
import IslandCore

public enum PowerStateParser {
    /// Описания источников питания IOKit → состояние встроенной батареи. Без батареи (Mac mini, Studio) nil
    public static func parse(descriptions: [[String: Any]], isLowPowerMode: Bool) -> PowerState? {
        guard let battery = descriptions.first(where: { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType })
        else { return nil }
        let current = battery[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = battery[kIOPSMaxCapacityKey] as? Int ?? 100
        return PowerState(
            isPluggedIn: (battery[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
            isCharging: battery[kIOPSIsChargingKey] as? Bool ?? false,
            level: max > 0 ? Double(current) / Double(max) : 0,
            isLowPowerMode: isLowPowerMode)
    }
}
