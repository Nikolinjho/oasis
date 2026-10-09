import IslandCore
import SwiftUI

/// Now Playing (ui-inspection 1.8, settings-07-now-playing*.jpg) без бейджа (решение 28.09) и живой волны
struct NowPlayingPage: View {
  @ObservedObject var settings: AppSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .nowPlaying)
      SettingsCard(title: nil) {
        MasterToggleRow(page: .nowPlaying, isOn: $settings.nowPlayingEnabled)
        if settings.nowPlayingEnabled {
          RowDivider()
          SliderRow(title: "Idle duration", value: $settings.idleDuration, range: 0...10, step: 1, format: .integer("s"))
          RowDivider()
          TileRow(
            tiles: WaveformStyle.allCases.map { style in
              Tile(value: style, title: Self.title(style), preview: AnyView(WaveformPreview(style: style)))
            }, selection: $settings.waveformStyle)
          RowDivider()
          ToggleRow(title: "Disable compact waveform", isOn: $settings.disableCompactWaveform)
          RowDivider()
          ToggleRow(title: "Disable artwork flip", isOn: $settings.disableArtworkFlip)
          RowDivider()
          ToggleRow(title: "Hide while source app is active", isOn: $settings.hideWhileSourceActive)
          RowDivider()
          ToggleRow(title: "Hide media title extras", isOn: $settings.hideTitleExtras)
          RowDivider()
          TileRow(
            tiles: PlayerExtraControl.allCases.map { control in
              Tile(
                value: control, title: control.isAvailable ? control.title : "\(control.title) · Soon",
                preview: AnyView(
                  Image(systemName: Self.symbol(control))
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)),
                isEnabled: control.isAvailable)
            }, selection: $settings.playerControl)
        }
      }
      if settings.nowPlayingEnabled {
        SettingsCard(title: "Source") {
          ToggleRow(title: "Automatic · \(settings.effectiveMediaSource.title)", isOn: $settings.automaticMediaSource)
          if !settings.automaticMediaSource {
            RowDivider()
            TileRow(
              tiles: MediaSourceChoice.allCases.map { source in
                Tile(
                  value: source, title: source.isAvailable ? source.title : "\(source.title) · Soon",
                  preview: AnyView(
                    Image(systemName: source == .system ? "gearshape.fill" : "music.note")
                      .font(.system(size: 18)).foregroundStyle(.white)),
                  isEnabled: source.isAvailable)
              }, selection: $settings.mediaSource, height: 56)
          }
        }
        if settings.effectiveMediaSource == .yandexMusic {
          YandexConnectionCard(connection: settings.yandexConnection)
        }
        SettingsCard(title: "Extension") {
          ToggleRow(title: "Quick Peek", isOn: $settings.quickPeek)
          if settings.quickPeek {
            RowDivider()
            ToggleRow(title: "When media changes", isOn: $settings.peekOnMediaChange)
            RowDivider()
            SliderRow(title: "Peek duration", value: $settings.peekDuration, range: 1...6, step: 1, format: .integer("s"))
          }
        }
      }
    }
  }

  private static func title(_ style: WaveformStyle) -> String {
    switch style {
    case .monochrome: "Monochrome"
    case .colored: "Colored"
    case .gradient: "Gradient"
    }
  }

  /// Иконки плиток доп. кнопки как у Alcove: сердце (AX «Love»), shuffle, repeat.1, ссылка
  private static func symbol(_ control: PlayerExtraControl) -> String {
    switch control {
    case .favorite: "heart.fill"
    case .shuffle: "shuffle"
    case .repeat: "repeat.1"
    case .copy: "link"
    }
  }
}

/// Превью плитки цвета волны: полоска как у Alcove (серая, красная, красно-оранжевая). Цвета — оценка по скрину
private struct WaveformPreview: View {
  let style: WaveformStyle

  var body: some View {
    Capsule()
      .fill(fill)
      .frame(width: 60, height: 5)
  }

  private var fill: AnyShapeStyle {
    switch style {
    case .monochrome: AnyShapeStyle(Color.gray)
    case .colored: AnyShapeStyle(SettingsPalette.accent)
    case .gradient: AnyShapeStyle(LinearGradient(colors: [SettingsPalette.accent, .orange], startPoint: .leading, endPoint: .trailing))
    }
  }
}
