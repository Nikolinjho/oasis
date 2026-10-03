import EventKit
import IslandCore
import SwiftUI

/// Calendar (ui-inspection 1.9, settings-08-calendar*.png) без Show weather on empty day (решение 03.10).
/// Главный тумблер выключен — остальные строки и карточки спрятаны, как на других страницах
struct CalendarPage: View {
  @ObservedObject var calendar: CalendarSettings
  let playSound: (IslandSound) -> Void
  /// Календари из store источника (CalendarBridge.calendars)
  let loadCalendars: () -> [CalendarInfo]
  @State private var calendars: [CalendarInfo] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      PageHeader(page: .calendar)
      SettingsCard(title: nil) {
        MasterToggleRow(page: .calendar, symbol: "calendar.badge.clock", isOn: $calendar.isEnabled)
        if calendar.isEnabled {
          RowDivider()
          SliderRow(
            title: "Time before event", value: $calendar.leadMinutes, range: 5...30, step: 5, format: .integer("m"))
          RowDivider()
          ToggleRow(title: "Play sound on calendar event", preview: { playSound(.event) }, isOn: $calendar.sound)
          RowDivider()
          ToggleRow(title: "Play hourly chime", preview: { playSound(.chime) }, isOn: $calendar.hourlyChime)
          RowDivider()
          ToggleRow(title: "Use calendar color", isOn: $calendar.useColor)
          RowDivider()
          ToggleRow(title: "Disable activity during events", isOn: $calendar.disableDuringEvents)
          RowDivider()
          ToggleRow(title: "Use event indicators", isOn: $calendar.eventIndicators)
          RowDivider()
          ToggleRow(title: "Always show month view", isOn: $calendar.monthView)
        }
      }
      if calendar.isEnabled {
        // у Alcove недоступна без геолокации; у нас поведения нет вовсе (решение 03.10)
        SettingsCard(title: nil) { LockedToggleRow(title: "Notify when time to leave") }
        SettingsCard(title: "Calendars") {
          if calendars.isEmpty {
            Text("No calendars: allow Oasis to access Calendars in System Settings")
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
              .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
          }
          ForEach(Array(calendars.enumerated()), id: \.element.id) { index, info in
            if index > 0 { RowDivider() }
            CalendarRow(info: info, calendar: calendar)
          }
        }
        SettingsCard(title: "Extension") {
          ToggleRow(title: "Quick Peek", isOn: $calendar.quickPeek)
          if calendar.quickPeek {
            RowDivider()
            ToggleRow(title: "Before event starts", isOn: $calendar.peekBeforeStart)
            RowDivider()
            ToggleRow(title: "When event is starting", isOn: $calendar.peekOnStart)
            RowDivider()
            SliderRow(
              title: "Peek duration", value: $calendar.peekDuration, range: 1...6, step: 1, format: .integer("s"))
            RowDivider()
            ToggleRow(title: "Use colored calendar indicator", isOn: $calendar.coloredIndicator)
          }
        }
      }
    }
    .onAppear { calendars = loadCalendars() }
    // EKEventStoreChanged приходит с фонового потока: @State меняем на главном
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged).receive(on: RunLoop.main)) { _ in
      calendars = loadCalendars()
    }
  }
}

/// Строка календаря: чекбокс в цвете календаря, глиф вида, название, меню режима справа (ui-inspection 1.9)
private struct CalendarRow: View {
  let info: CalendarInfo
  @ObservedObject var calendar: CalendarSettings

  var body: some View {
    let included = calendar.isIncluded(info.id)
    let color = Color(red: info.color.red, green: info.color.green, blue: info.color.blue)
    HStack(spacing: 8) {
      Button {
        calendar.setIncluded(!included, info.id)
      } label: {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(included ? color : .clear)
          .strokeBorder(color, lineWidth: included ? 0 : 1.5)
          .frame(width: 16, height: 16)
          .overlay {
            if included {
              Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
            }
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(info.title)
      .accessibilityValue(included ? "on" : "off")
      if let glyph = Self.glyph(info.kind) {
        Image(systemName: glyph).font(.system(size: 12)).foregroundStyle(.secondary)
      }
      Text(info.title).lineLimit(1)
      Spacer()
      Menu {
        modeButton(.both)
        Divider()
        modeButton(.liveActivity)
        modeButton(.expandedView)
      } label: {
        Text(calendar.mode(for: info.id).title)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .frame(height: 42)
  }

  private func modeButton(_ mode: CalendarDisplayMode) -> some View {
    Button {
      calendar.setMode(mode, info.id)
    } label: {
      if calendar.mode(for: info.id) == mode {
        Label(mode.title, systemImage: "checkmark")
      } else {
        Text(mode.title)
      }
    }
  }

  /// Праздники и подписки — волны (у Alcove `)))`), Birthdays — подарок. Символы близкие, не точные
  private static func glyph(_ kind: CalendarInfo.Kind) -> String? {
    switch kind {
    case .regular: nil
    case .subscription: "dot.radiowaves.right"
    case .birthdays: "gift"
    }
  }
}

/// Заблокированная строка: затенена, замок вместо тумблера, не переключается (у Alcove — нет геолокации)
private struct LockedToggleRow: View {
  let title: String

  var body: some View {
    HStack(spacing: 6) {
      Text(title)
      Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(.secondary)
      Spacer()
      Toggle("", isOn: .constant(false))
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(true)
    }
    .padding(.horizontal, 12)
    .frame(height: 42)
    .opacity(0.45)
    .help("Not available")
  }
}
