import AppKit
import IslandCore
import SwiftUI

/// Окно настроек: сайдбар 200 pt и прокрутка контента (ui-inspection 1.1)
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var page: SettingsPage = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $page)
                .frame(width: 200)
            Divider()
            ScrollView {
                GeneralPage(settings: settings)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 687 pt у Alcove — рамка окна вместе с заголовком 28 pt
        .frame(width: 620, height: 659)
    }
}

struct SettingsSidebar: View {
    @Binding var selection: SettingsPage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(SettingsPage.allCases.enumerated()), id: \.element) { index, page in
                if let group = page.group, index == 0 || SettingsPage.allCases[index - 1].group != group {
                    Text(group)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                        .padding(.leading, 10)
                }
                SidebarRow(page: page, isSelected: page == selection)
                    .onTapGesture {
                        if page.isAvailable { selection = page }
                    }
            }
            Spacer()
        }
        .padding(8)
    }
}

/// Строка сайдбара 38 pt. Незаготовленная страница затенена и подписана Soon, как File Tray у Alcove
struct SidebarRow: View {
    let page: SettingsPage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            SettingsIcon(page: page, side: 22)
            Text(page.title).font(.system(size: 13))
            Spacer()
            if !page.isAvailable {
                Text("Soon")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.1)))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.1) : .clear))
        .opacity(page.isAvailable ? 1 : 0.45)
        .contentShape(Rectangle())
    }
}

/// General: строки из раздела 1.2 ui-inspection, которые нужны MVP. Force simulated notch и Display on — P2
struct GeneralPage: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(page: .general)
            SettingsCard(title: nil) {
                ToggleRow(title: "Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { _ in
                        // SMAppService.status читается синхронно, но алерт об ошибке не должен
                        // блокировать сеттер Binding: переключение уходит в Task
                        Task { @MainActor in
                            do {
                                try LoginItem.toggle()
                            } catch {
                                LoginItem.presentError(error, on: NSApp.keyWindow)
                            }
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }))
            }
            SettingsCard(title: "Behaviour") {
                ToggleRow(title: "Expand on hover", info: "Disables certain interactions", isOn: $settings.expandOnHover)
                if settings.expandOnHover {
                    RowDivider()
                    SliderRow(title: "Hover duration", value: hoverDuration, range: 0...0.6, step: 0.1, unit: "s")
                }
            }
        }
        // launchAtLogin меняют и снаружи (пункт меню, System Settings): подхватываем при появлении
        // страницы и при возврате окна в фокус, а не только из своего тумблера
        .onAppear { launchAtLogin = LoginItem.isEnabled }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            launchAtLogin = LoginItem.isEnabled
        }
    }

    /// Слайдер шагает по 0.1, но Double-арифметика даёт 0.30000000000000004: округляем перед записью,
    /// иначе в UserDefaults и в подписи попадает мусор после запятой
    private var hoverDuration: Binding<Double> {
        Binding(
            get: { settings.hoverDuration },
            set: { settings.hoverDuration = (($0 * 10).rounded()) / 10 })
    }
}
