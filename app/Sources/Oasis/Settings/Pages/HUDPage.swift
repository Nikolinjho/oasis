import IslandCore
import IslandUI
import SwiftUI

/// Display и Sound (ui-inspection 1.6, 1.7): одна карточка, строки одинаковые, у Sound ещё плитки иконки.
/// Главный тумблер выключен — клавиши этого вида у системы
struct HUDPage: View {
  @ObservedObject var settings: AppSettings
  let kind: HUDKind

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: page)
      SettingsCard(title: nil) {
        MasterToggleRow(page: page, isOn: kind == .volume ? $settings.soundHUDEnabled : $settings.displayHUDEnabled)
        if kind == .volume ? settings.soundHUDEnabled : settings.displayHUDEnabled {
          RowDivider()
          SliderRow(
            title: "Duration", value: kind == .volume ? $settings.soundHUDDuration : $settings.displayHUDDuration,
            range: 1...2, step: 0.5, format: .decimal("s"))
          RowDivider()
          TileRow(
            tiles: styles.map { style in
              Tile(
                value: style, title: Self.title(style),
                preview: AnyView(
                  LevelBar(level: 0.6, style: style).frame(width: 60, height: 5)))
            }, selection: kind == .volume ? $settings.soundHUDStyle : $settings.displayHUDStyle)
          RowDivider()
          ToggleRow(
            title: "Show percentage",
            isOn: kind == .volume ? $settings.soundHUDPercentage : $settings.displayHUDPercentage)
          RowDivider()
          ToggleRow(title: "Hide label", isOn: kind == .volume ? $settings.soundHUDHideLabel : $settings.displayHUDHideLabel)
          RowDivider()
          TileRow(
            tiles: [
              Tile(value: HUDSpeed.smooth, title: "Smooth", preview: AnyView(glyph("tortoise.fill"))),
              Tile(value: HUDSpeed.fast, title: "Fast", preview: AnyView(glyph("hare.fill"))),
              Tile(value: HUDSpeed.instant, title: "Instant", preview: AnyView(glyph("bolt.fill"))),
            ], selection: kind == .volume ? $settings.soundHUDSpeed : $settings.displayHUDSpeed)
          if kind == .volume {
            RowDivider()
            TileRow(
              tiles: [
                Tile(value: HUDIcon.symbol, title: "Show symbol", preview: AnyView(glyph("speaker.wave.2.fill"))),
                Tile(value: HUDIcon.device, title: "Show device", preview: AnyView(glyph("airpods"))),
              ], selection: $settings.soundHUDIcon, height: 48)
          }
        }
      }
    }
  }

  private var page: SettingsPage { kind == .volume ? .sound : .display }

  /// У громкости третий стиль Decibel, у яркости Glow
  private var styles: [HUDBarStyle] { kind == .volume ? [.white, .accent, .decibel] : [.white, .accent, .glow] }

  private static func title(_ style: HUDBarStyle) -> String {
    switch style {
    case .white: "White"
    case .accent: "Accent"
    case .decibel: "Decibel"
    case .glow: "Glow"
    }
  }

  private func glyph(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(.white)
  }
}
