import IslandCore
import SwiftUI

/// Battery (ui-inspection 1.3, settings-02-battery.jpg): одна карточка. Главный тумблер выключен — остальные строки спрятаны
struct BatteryPage: View {
  @ObservedObject var settings: AppSettings
  let playSound: (IslandSound) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .battery)
      SettingsCard(title: nil) {
        MasterToggleRow(page: .battery, isOn: $settings.batteryEnabled)
        if settings.batteryEnabled {
          RowDivider()
          SliderRow(title: "Duration", value: $settings.batteryDuration, range: 2.5...6, step: 0.5, format: .decimal("s"))
          RowDivider()
          ToggleRow(title: "Notify on low power mode", isOn: $settings.notifyLowPower)
          RowDivider()
          ToggleRow(title: "Warn on low battery", isOn: $settings.warnLowBattery)
          RowDivider()
          SliderRow(
            title: "Low battery threshold", value: $settings.lowBatteryThreshold, range: 0.1...0.3, step: 0.1,
            format: .percent)
          RowDivider()
          ToggleRow(title: "Play sound on low battery", preview: { playSound(.lowBattery) }, isOn: $settings.lowBatterySound)
          RowDivider()
          ToggleRow(title: "Hide label", isOn: $settings.hideBatteryLabel)
          RowDivider()
          ToggleRow(title: "Hide percentage", isOn: $settings.hideBatteryPercentage)
        }
      }
    }
  }
}
