import AppKit
import IslandCore
import SwiftUI

/// Окно настроек: сайдбар 200 pt и прокрутка контента (ui-inspection 1.1)
struct SettingsView: View {
  @ObservedObject var settings: AppSettings
  /// Кнопки ▶ превью звука: AppDelegate подключает SoundPlayer
  var playSound: (IslandSound) -> Void = { _ in }
  /// Заголовок окна у Alcove — название страницы
  var onPageChange: (SettingsPage) -> Void = { _ in }
  @State private var page: SettingsPage = .general

  var body: some View {
    HStack(spacing: 0) {
      // С группой Modules 14 строк не влезают в 659 pt: сайдбар прокручивается, высоту окна держим по Alcove
      ScrollView(.vertical, showsIndicators: false) {
        SettingsSidebar(selection: $page)
      }
      .frame(width: 200)
      Divider()
      ScrollView {
        pageContent
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    // 687 pt у Alcove — рамка окна вместе с заголовком 28 pt
    .frame(width: 620, height: 659)
    .onChange(of: page) { _, new in onPageChange(new) }
  }

  /// Страницы P2 подключаются по мере готовности (задачи 4–9): недоступные в сайдбар не выбираются
  @ViewBuilder
  private var pageContent: some View {
    switch page {
    case .general: GeneralPage(settings: settings)
    case .battery: BatteryPage(settings: settings, playSound: playSound)
    case .connectivity: ConnectivityPage(settings: settings, playSound: playSound)
    case .display: HUDPage(settings: settings, kind: .brightness)
    case .sound: HUDPage(settings: settings, kind: .volume)
    case .nowPlaying: NowPlayingPage(settings: settings)
    case .calendar: CalendarPage(calendar: settings.calendar, playSound: playSound)
    default: EmptyView()
    }
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
      // «Claude Code» рядом с бейджем Soon впритык: заголовок не уступает место отступу
      Text(page.title).font(.system(size: 13)).lineLimit(1).layoutPriority(1)
      Spacer(minLength: 0)
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
        .fill(isSelected ? Color.primary.opacity(0.1) : .clear)
    )
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
        ToggleRow(
          title: "Launch at login",
          isOn: Binding(
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
        RowDivider()
        ToggleRow(
          title: "Hide menu bar icon", info: "Right-click the island to open the menu",
          isOn: $settings.hideMenuBarIcon)
      }
      SettingsCard(title: "Behaviour") {
        ToggleRow(title: "Play sounds", isOn: $settings.playSounds)
        RowDivider()
        ToggleRow(title: "Expand on hover", info: "Disables certain interactions", isOn: $settings.expandOnHover)
        if settings.expandOnHover {
          RowDivider()
          SliderRow(title: "Hover duration", value: $settings.hoverDuration, range: 0...0.6, step: 0.1, unit: "s")
        }
      }
      // Most Recent включён — плитки и Force enable прячутся, текущая плитка дописана в подпись тумблера (ui-inspection 1.2)
      SettingsCard(title: "Idle Activity") {
        ToggleRow(
          title: settings.mostRecentActivity ? "Most Recent ∙ \(settings.idleActivity.title)" : "Most Recent",
          icon: "clock.arrow.circlepath", isOn: $settings.mostRecentActivity)
        if !settings.mostRecentActivity {
          RowDivider()
          TileRow(
            tiles: [
              Tile(value: IdleActivity.none, title: "None", preview: AnyView(tileGlyph("nosign"))),
              Tile(value: IdleActivity.playing, title: "Playing", preview: AnyView(tileGlyph("play.fill"))),
              Tile(value: IdleActivity.calendar, title: "Calendar", preview: AnyView(tileGlyph("calendar"))),
              Tile(value: IdleActivity.duo, title: "Duo", preview: AnyView(tileGlyph("rectangle.split.2x1.fill"))),
            ], selection: $settings.idleActivity, height: 52)
          RowDivider()
          ToggleRow(title: "Force enable activity", isOn: $settings.forceEnableActivity)
        }
      }
      SettingsCard(title: "Gestures") {
        ToggleRow(title: "Natural movement", isOn: $settings.naturalMovement)
        RowDivider()
        ToggleRow(
          title: "Swipe to dismiss activity", info: "Swipe vertically to toggle activity",
          isOn: $settings.swipeToDismiss)
      }
      SettingsCard(title: "Tuning") {
        // onEditingChanged — подсказка острова, пока ползунок зажат (Task 17t)
        SliderRow(
          title: "Notch width", value: $settings.notchWidthOffset, range: -2...2, step: 1,
          format: .integer("pt"), onEditingChanged: settings.notchWidthDragChanged)
        RowDivider()
        SliderRow(
          title: "Notch height", value: $settings.notchHeightOffset, range: -2...2, step: 1,
          format: .integer("pt"), onEditingChanged: settings.notchHeightDragChanged)
      }
    }
    // launchAtLogin меняют и снаружи (пункт меню, System Settings): подхватываем при появлении
    // страницы и при возврате окна в фокус, а не только из своего тумблера
    .onAppear { launchAtLogin = LoginItem.isEnabled }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      launchAtLogin = LoginItem.isEnabled
    }
  }

  private func tileGlyph(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(.white)
  }
}
