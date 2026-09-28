import IslandCore
import SwiftUI

/// Содержимое уведомления по виду
struct AlertView: View {
    let alert: IslandAlert
    let notchWidth: CGFloat

    var body: some View {
        switch alert {
        case let .charging(level):
            // решение пользователя 28.09: у Charging процент не пишем, только батарейка
            BatteryAlertView(label: "Charging", level: level, showsPercent: false, fill: IslandPalette.charging, notchWidth: notchWidth)
        case let .lowBattery(level):
            BatteryAlertView(label: "Low Battery", level: level, showsPercent: true, fill: IslandPalette.lowBattery, notchWidth: notchWidth)
        case let .lowPower(level):
            // по ожидаемому виду из репорта: «Low Power Mode» и батарейка без процента
            BatteryAlertView(label: "Low Power Mode", level: level, showsPercent: false, fill: IslandPalette.lowPower, notchWidth: notchWidth)
        }
    }
}

/// Уведомление батареи высотой 32: подпись слева, процент и батарейка справа (Charging — rec2/states-sheet.png,
/// Low Battery и Low Power не снимались: тот же паттерн, но своя ширина под подпись — IslandGeometry.size(for:)).
/// Шрифт и отступы как у HUD, отдельно не мерили
struct BatteryAlertView: View {
    let label: String
    let level: Double
    let showsPercent: Bool
    let fill: Color
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IslandPalette.foreground)
                // без этого длинная подпись (Low Battery, Low Power Mode) переносится на вторую строку
                // или уезжает вправо под вырез — она должна целиком остаться в левом крыле
                .lineLimit(1)
                .fixedSize()
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
        .padding(.horizontal, 14)
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
