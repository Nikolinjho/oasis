import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct ActivityCompactViewTests {
    static let red = RGB(red: 1, green: 0.27, blue: 0.23)
    static let track = RGB(red: 0.35, green: 0.1, blue: 0.1)

    @Test("Кольцо рисует прогресс в пределах 0…1")
    func ringClamp() {
        #expect(ActivityRing.clamped(-0.2) == 0)
        #expect(ActivityRing.clamped(0.4) == 0.4)
        #expect(ActivityRing.clamped(1.7) == 1)
    }

    @MainActor
    @Test("Снимки: кольцо, текст и строка peek")
    func snapshots() throws {
        let compact = CGSize(width: 250, height: 32)
        let peek = CGSize(width: 270, height: 73.5)
        let cases: [(String, ActivityLayout, CGSize)] = [
            ("activity-ring", ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red,
                                             indicator: .ring(progress: 0.35, color: Self.red, track: Self.track)), compact),
            ("activity-text", ActivityLayout(symbol: "calendar.badge.clock", symbolColor: Self.red,
                                             indicator: .text("12s", color: Self.red)), compact),
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
                ActivityCompactView(layout: layout, notchWidth: 186)
                    .frame(width: size.width, height: size.height, alignment: .top)
            }
            try Snapshot.write(view, size: size, name: name)
        }
    }
}
