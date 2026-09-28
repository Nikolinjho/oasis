import AppKit
import IslandCore
import SwiftUI

/// Компакт активности 32 pt: иконка 18×15 слева, кольцо 16 pt или текст по ширине справа, вырез между ними.
/// Ширину острова под индикатор считает ActivityLayout.width — здесь просто рисуем в отведённое место.
/// С line снизу добавляется строка peek (высота формы 73.5). Паддинг и кегль индикатора — общие константы
/// ActivityLayout (compactPadding, indicatorFontSize), чтобы контракт и рисование не разъехались
struct ActivityCompactView: View {
    let layout: ActivityLayout
    let notchWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: layout.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(layout.symbolColor))
                    .frame(width: ActivityLayout.iconWidth, height: 15)
                Spacer(minLength: notchWidth)
                indicator
            }
            .padding(.horizontal, ActivityLayout.compactPadding)
            .frame(height: 32)

            if let line = layout.line {
                ActivityLine(line: line)
                    .padding(.horizontal, 14)
                    .frame(height: 41.5)
                    .transition(.slot)
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch layout.indicator {
        case let .ring(progress, color, track):
            ActivityRing(progress: progress, color: Color(color), track: Color(track))
                .frame(width: ActivityLayout.ringWidth, height: ActivityLayout.ringWidth)
        case let .text(text, color):
            Text(text)
                .font(.system(size: ActivityLayout.indicatorFontSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color(color))
                // держит натуральную ширину текста: без этого перенос на две строки при нехватке места.
                // Само место под текст должно быть посчитано заранее через ActivityLayout.width
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// Ширина индикатора без построения SwiftUI-дерева — нужна вызывающей стороне (Task 4/5/7) заранее,
    /// чтобы посчитать ActivityLayout.width. Кольцо — фиксированные 16 pt, текст — метрика того же шрифта,
    /// что рисует .text выше (indicatorFontSize, полужирный, моноширинные цифры), с округлением вверх
    nonisolated static func indicatorWidth(_ indicator: ActivityLayout.Indicator) -> CGFloat {
        switch indicator {
        case .ring:
            return ActivityLayout.ringWidth
        case let .text(text, _):
            let font = NSFont.monospacedDigitSystemFont(ofSize: ActivityLayout.indicatorFontSize, weight: .semibold)
            let size = (text as NSString).size(withAttributes: [.font: font])
            return size.width.rounded(.up)
        }
    }
}

/// Кольцо 16 pt, линия 3 pt, начало сверху. Толщину не мерили, оценка по кадру cal-compact.jpg
struct ActivityRing: View {
    let progress: Double
    let color: Color
    let track: Color

    nonisolated static func clamped(_ progress: Double) -> Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: 3)
            Circle()
                .trim(from: 0, to: Self.clamped(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.smooth(duration: 0.3), value: progress)
    }
}

/// «▌название ⏳ 59s»: полоска в цвете календаря, название белым, иконка и время серым (ui-inspection 3.5)
struct ActivityLine: View {
    let line: ActivityLayout.Line

    var body: some View {
        HStack(spacing: 6) {
            if let bar = line.bar {
                Capsule().fill(Color(bar)).frame(width: 3, height: 16)
            }
            Text(line.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IslandPalette.foreground)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let symbol = line.trailingSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(IslandPalette.secondary)
            }
            if let trailing = line.trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(IslandPalette.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}
