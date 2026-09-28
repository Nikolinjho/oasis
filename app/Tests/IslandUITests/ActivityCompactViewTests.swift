import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct ActivityCompactViewTests {
    static let red = RGB(red: 1, green: 0.27, blue: 0.23)
    static let track = RGB(red: 0.35, green: 0.1, blue: 0.1)
    static let notchWidth: CGFloat = 186

    @Test("Кольцо рисует прогресс в пределах 0…1")
    func ringClamp() {
        #expect(ActivityRing.clamped(-0.2) == 0)
        #expect(ActivityRing.clamped(0.4) == 0.4)
        #expect(ActivityRing.clamped(1.7) == 1)
    }

    /// Ширина текста тем же шрифтом, что рисует индикатор (13pt semibold, monospacedDigit) —
    /// вход для ActivityLayout.width, а не хардкод
    @MainActor
    static func measuredWidth(_ text: String) -> CGFloat {
        NSHostingView(rootView: Text(text)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()).fittingSize.width
    }

    @MainActor
    static func render(_ view: some View, size: CGSize) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw Snapshot.RenderError() }
        return NSBitmapImageRep(cgImage: image)
    }

    /// Крайние закрашенные (не чёрные) пиксели по строке в точках — тем же способом, которым в ревью
    /// нашли перенос под вырез по снимку. Возвращает кластеры слева направо: иконка первая, индикатор последний
    static func coloredClusters(_ bitmap: NSBitmapImageRep, rowPoint: CGFloat, scale: Int) -> [(left: CGFloat, right: CGFloat)] {
        let y = Int(rowPoint) * scale
        var clusters: [(left: CGFloat, right: CGFloat)] = []
        var start: Int?
        for x in 0..<bitmap.pixelsWide {
            let bright = bitmap.colorAt(x: x, y: y)?.brightnessComponent ?? 0
            if bright > 0.08 {
                if start == nil { start = x }
            } else if let s = start {
                clusters.append((CGFloat(s) / CGFloat(scale), CGFloat(x) / CGFloat(scale)))
                start = nil
            }
        }
        if let s = start { clusters.append((CGFloat(s) / CGFloat(scale), CGFloat(bitmap.pixelsWide) / CGFloat(scale))) }
        return clusters
    }

    @MainActor
    @Test("Снимки: кольцо, текст и строка peek")
    func snapshots() throws {
        let peek = CGSize(width: 270, height: 73.5)
        let ringWidth = ActivityLayout.width(notchWidth: Self.notchWidth, indicatorWidth: 16)
        let cases: [(String, ActivityLayout, CGSize)] = [
            ("activity-ring", ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red,
                                             indicator: .ring(progress: 0.35, color: Self.red, track: Self.track)),
             CGSize(width: ringWidth, height: 32)),
            ("activity-text", ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red,
                                             indicator: .text("12s", color: Self.red)),
             CGSize(width: ActivityLayout.width(notchWidth: Self.notchWidth, indicatorWidth: Self.measuredWidth("12s")), height: 32)),
            // напоминание за 15 минут шире отсчёта секунд — тот же вырез не должен переносить или обрезать текст
            ("activity-text-wide", ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red,
                                             indicator: .text("15m", color: Self.red)),
             CGSize(width: ActivityLayout.width(notchWidth: Self.notchWidth, indicatorWidth: Self.measuredWidth("15m")), height: 32)),
            // ширина peek — про строку Line снизу (bar+title+иконка+время), формат которой ещё не в контракте
            // (Task 4/5); 270 уже больше минимума под кольцо (ringWidth), так что вырез не пострадает
            ("activity-peek", ActivityLayout(
                symbol: "calendar.badge.clock", symbolColor: Self.red,
                indicator: .ring(progress: 0.02, color: Self.red, track: Self.track),
                line: .init(bar: RGB(red: 0.35, green: 0.85, blue: 0.35), title: "тест для alcove",
                            trailingSymbol: "hourglass", trailing: "59s")), peek),
        ]
        for (name, layout, size) in cases {
            let view = ZStack(alignment: .top) {
                IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: IslandGeometry.bottomRadius(forHeight: size.height)), shoulder: 0)
                    .fill(IslandPalette.background)
                ActivityCompactView(layout: layout, notchWidth: Self.notchWidth)
                    .frame(width: size.width, height: size.height, alignment: .top)
            }
            try Snapshot.write(view, size: size, name: name)
        }
    }

    /// Регрессия на перенос/наезд индикатора под вырез (найдено в ревью Task 3): при ширине компакта,
    /// посчитанной ActivityLayout.width под естественную ширину индикатора, индикатор должен начинаться
    /// не раньше правого края выреза и заканчиваться не ближе 12 pt до правого края формы
    @MainActor
    @Test("Индикатор умещается в своё крыло по ActivityLayout.width", arguments: ["12s", "15m", "59m"])
    func indicatorFitsWing(_ text: String) throws {
        let indicatorWidth = Self.measuredWidth(text)
        let width = ActivityLayout.width(notchWidth: Self.notchWidth, indicatorWidth: indicatorWidth)
        let layout = ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red, indicator: .text(text, color: Self.red))
        let bitmap = try Self.render(ActivityCompactView(layout: layout, notchWidth: Self.notchWidth), size: CGSize(width: width, height: 32))
        let clusters = Self.coloredClusters(bitmap, rowPoint: 16, scale: 2)
        let indicator = try #require(clusters.last)
        let notchRight = (width + Self.notchWidth) / 2
        // допуск на антиалиасинг глифа, оценка
        #expect(indicator.left >= notchRight - 1)
        #expect(width - indicator.right >= 12 - 1.5)
    }

    /// Тот же контракт для кольца: ширина индикатора фиксирована (16 pt) и меньше иконки (18), поэтому
    /// крыло берёт максимум — 12+18=30, как у иконки, и кольцо не должно уходить ни в вырез, ни за паддинг
    @MainActor
    @Test("Кольцо умещается в своё крыло по ActivityLayout.width")
    func ringFitsWing() throws {
        let width = ActivityLayout.width(notchWidth: Self.notchWidth, indicatorWidth: 16)
        let layout = ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red,
                                     indicator: .ring(progress: 0.35, color: Self.red, track: Self.track))
        let bitmap = try Self.render(ActivityCompactView(layout: layout, notchWidth: Self.notchWidth), size: CGSize(width: width, height: 32))
        let clusters = Self.coloredClusters(bitmap, rowPoint: 16, scale: 2)
        let ring = try #require(clusters.last)
        let notchRight = (width + Self.notchWidth) / 2
        #expect(ring.left >= notchRight - 1)
        #expect(width - ring.right >= 12 - 1.5)
    }

    /// Реальный компакт календаря — 250 pt (ui-inspection 3.5, замер ~250). Этим шрифтом даже короткое "12s"
    /// (измерено 24 pt) требует 258 pt по контракту — 250 уже не хватает. Значит компакт календаря нельзя
    /// рисовать в хардкод 250: ширину острова под него должен считать ActivityLayout.width (Task 4)
    @MainActor
    @Test("При реальной ширине компакта 250pt контракт требует ActivityLayout.width, не хардкод")
    func realCompactWidthNeedsContractWidth() {
        let needed = ActivityLayout.width(notchWidth: Self.notchWidth, indicatorWidth: Self.measuredWidth("12s"))
        #expect(needed > 250)
    }
}
