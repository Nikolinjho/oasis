import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct OpenScaleTests {
    static let info = NowPlayingInfo(title: "Fire", artist: "Demo Artist", isPlaying: true, duration: 200, elapsed: 30)

    @Test("Масштаб контента — доля ширины формы, на перелёте больше 1")
    func scaleFollowsWidth() {
        let target = IslandGeometry.expanded
        #expect(abs(OpenScale.scale(size: CGSize(width: 279.5, height: 118), target: target) - 0.81) < 0.001)
        #expect(OpenScale.scale(size: target, target: target) == 1)
        #expect(OpenScale.scale(size: CGSize(width: 359.6, height: 188), target: target) > 1)
    }

    @MainActor
    @Test("Снимок середины раскрытия: контент уменьшен от верха по центру и обрезан формой")
    func midOpenSnapshot() throws {
        let mid = IslandShapeSpec(size: CGSize(width: 280, height: 118), bottomRadius: 25, shoulder: 14)
        let view = ZStack(alignment: .top) {
            IslandShape(spec: mid).fill(IslandPalette.background)
            PlayerView(info: Self.info, onAction: { _ in })
                .modifier(OpenScale(size: mid.size, target: IslandGeometry.expanded, scalesContent: true))
                .clipShape(IslandShape(spec: mid, shoulder: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        try Snapshot.write(view, size: IslandGeometry.windowSize, name: "open-mid")
    }
}
