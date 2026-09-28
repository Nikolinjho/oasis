import IslandCore
import SwiftUI

/// Содержимое уведомления по виду
struct AlertView: View {
    let alert: IslandAlert
    let notchWidth: CGFloat

    var body: some View {
        switch alert {
        case let .charging(level):
            ChargingView(level: level, notchWidth: notchWidth)
        }
    }
}

/// Charging 350×32: подпись слева, батарейка справа (rec2/states-sheet.png).
/// Шрифт и отступы как у HUD: отдельно не мерили
/// решение пользователя 28.09: у Charging процент не пишем
struct ChargingView: View {
    let level: Double
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("Charging")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IslandPalette.foreground)
            Spacer(minLength: notchWidth)
            BatteryGlyph(level: level, fill: IslandPalette.charging)
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
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
