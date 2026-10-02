import IslandCore
import SwiftUI

/// Содержимое уведомления по виду
struct AlertView: View {
  let alert: IslandAlert
  let notchWidth: CGFloat
  var battery = BatteryAlertStyle()

  var body: some View {
    switch alert {
    case .charging(let level):
      // решение пользователя 28.09: у Charging процент не пишем, только батарейка
      BatteryAlertView(label: label("Charging"), level: level, showsPercent: false, fill: IslandPalette.charging, notchWidth: notchWidth)
    case .lowBattery(let level):
      BatteryAlertView(
        label: label("Low Battery"), level: level, showsPercent: !battery.hidesPercentage,
        fill: IslandPalette.lowBattery, notchWidth: notchWidth)
    case .lowPower(let level):
      // по ожидаемому виду из репорта: «Low Power Mode» и батарейка без процента
      BatteryAlertView(
        label: label("Low Power Mode"), level: level, showsPercent: false, fill: IslandPalette.lowPower, notchWidth: notchWidth)
    case .calendarReminder(let reminder):
      ActivityCompactView(layout: ActivityLayouts.reminder(reminder), notchWidth: notchWidth)
    case .airpods(let info):
      ActivityCompactView(layout: ActivityLayouts.airpods(info), notchWidth: notchWidth)
    }
  }

  private func label(_ text: String) -> String? {
    battery.hidesLabel ? nil : text
  }
}

/// Уведомление батареи высотой 32: подпись слева, процент и батарейка справа (Charging — rec2/states-sheet.png,
/// Low Battery и Low Power не снимались: тот же паттерн, но своя ширина под подпись — IslandGeometry.size(for:notch:reminderIndicatorWidth:).
/// Шрифт и отступы как у HUD, отдельно не мерили
struct BatteryAlertView: View {
  let label: String?
  let level: Double
  let showsPercent: Bool
  let fill: Color
  let notchWidth: CGFloat

  /// Боковой отступ подписи и правого блока. Тот же 14, что учтён в IslandGeometry.BatteryAlertWing
  /// при расчёте ширины Low Battery/Low Power — держать в одном месте, чтобы вью и геометрия не разъехались.
  /// nonisolated: константа, а не состояние UI — тест читает её вне MainActor
  nonisolated static let padding: CGFloat = 14

  var body: some View {
    HStack(spacing: 0) {
      if let label {
        Text(label)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(IslandPalette.foreground)
          // без этого длинная подпись (Low Battery, Low Power Mode) переносится на вторую строку
          // или уезжает вправо под вырез — она должна целиком остаться в левом крыле
          .lineLimit(1)
          .fixedSize()
      }
      Spacer(minLength: notchWidth)
      HStack(spacing: 6) {
        if showsPercent {
          Text(Self.percent(level))
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(IslandPalette.foreground)
        }
        BatteryGlyph(level: level, fill: fill)
      }
    }
    .padding(.horizontal, Self.padding)
    .frame(height: 32)
  }

  nonisolated static func percent(_ level: Double) -> String {
    "\(Int((min(max(level, 0), 1) * 100).rounded()))%"
  }
}

/// Батарейка 25×12 с носиком: заливка по уровню. Пропорции по кадру, замера нет
struct BatteryGlyph: View {
  let level: Double
  let fill: Color

  var body: some View {
    HStack(spacing: 1) {
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
          .stroke(IslandPalette.foreground.opacity(0.35), lineWidth: 1)
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(fill)
          .frame(width: max(2, 21 * min(max(level, 0), 1)))
          .padding(2)
      }
      .frame(width: 25, height: 12)
      RoundedRectangle(cornerRadius: 1)
        .fill(IslandPalette.foreground.opacity(0.35))
        .frame(width: 1.5, height: 4)
    }
  }
}
