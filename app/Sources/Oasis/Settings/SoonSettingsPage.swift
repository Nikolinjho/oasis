import AppKit
import IslandCore
import SwiftUI

struct SoonSettingsPage: View {
  @ObservedObject var settings: SoonSettings
  @Bindable var module: SoonModule

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .soon)
      SettingsCard(title: nil) {
        ToggleRow(title: "Soon", info: "Короткие напоминания с произвольным сроком", isOn: $settings.enabled)
      }
      if settings.enabled {
        SettingsCard(title: "Notifications") {
          ToggleRow(title: "Show in island", isOn: $settings.showInIsland)
          RowDivider()
          ToggleRow(title: "System notifications", isOn: $settings.systemNotifications)
          if settings.systemNotifications {
            VStack(alignment: .leading, spacing: 6) {
              Text(authorizationText).font(.system(size: 11)).foregroundStyle(.secondary)
              if module.delivery.authorization == .denied {
                Button("Открыть настройки macOS") {
                  if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                    NSWorkspace.shared.open(url)
                  }
                }
                .buttonStyle(.plain)
                .foregroundStyle(SettingsPalette.accent)
              }
              if let error = module.delivery.error {
                Text(error).font(.system(size: 11)).foregroundStyle(.secondary)
              }
            }
            .padding(.bottom, 8)
          }
          RowDivider()
          ToggleRow(title: "Play sound", isOn: $settings.playSound)
        }
        SettingsCard(title: "Behaviour") {
          ToggleRow(title: "Hide peek in fullscreen", isOn: $settings.hidePeekInFullscreen)
        }
        HStack {
          Button("New reminder…") { module.perform(.create) }
            .foregroundStyle(SettingsPalette.accent)
          Spacer()
          Button("Clear completed") { module.perform(.clearCompleted) }
            .disabled(!module.reminders.contains { $0.state == .completed })
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .padding(.top, 4)
        .padding(.bottom, 22)
      }
      if let error = module.error {
        Text(error).font(.system(size: 11)).foregroundStyle(.red)
      }
    }
    .onAppear { module.systemTimeChanged() }
  }

  private var authorizationText: String {
    switch module.delivery.authorization {
    case .unknown: "Проверяем разрешение macOS…"
    case .notDetermined: "Разрешение macOS будет запрошено при создании напоминания."
    case .denied: "Notifications are disabled in macOS. При открытом Oasis работает остров."
    case .authorized, .provisional: "Уведомления разрешены в macOS."
    }
  }
}
