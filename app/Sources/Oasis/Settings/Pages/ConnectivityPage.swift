import IslandCore
import SwiftUI

/// Connectivity (ui-inspection 1.4, settings-03-connectivity.jpg). Стиль 3D models (видео моделей) отложен в P3:
/// плитка есть, но затенена, выбран Symbols
struct ConnectivityPage: View {
  @ObservedObject var settings: AppSettings
  let playSound: (IslandSound) -> Void

  private enum Style: Hashable { case models, symbols }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .connectivity)
      SettingsCard(title: nil) {
        MasterToggleRow(page: .connectivity, isOn: $settings.connectivityEnabled)
        if settings.connectivityEnabled {
          RowDivider()
          SliderRow(
            title: "Duration", value: $settings.connectivityDuration, range: 2.5...6, step: 0.5,
            format: .decimal("s"))
          RowDivider()
          ToggleRow(title: "Warn on low battery", isOn: $settings.warnHeadphonesLowBattery)
          RowDivider()
          SliderRow(
            title: "Low battery threshold", value: $settings.headphonesLowBatteryThreshold,
            range: 0.1...0.3, step: 0.1, format: .percent)
          RowDivider()
          ToggleRow(
            title: "Play sound on low battery", preview: { playSound(.lowBattery) },
            isOn: $settings.headphonesLowBatterySound)
          RowDivider()
          TileRow(
            tiles: [
              Tile(value: Style.models, title: "3D models", preview: AnyView(glyph("headphones")), isEnabled: false),
              Tile(value: Style.symbols, title: "Symbols", preview: AnyView(glyph("airpodspro"))),
            ], selection: .constant(.symbols), height: 48)
        }
      }
    }
  }

  private func glyph(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(.white)
  }
}
