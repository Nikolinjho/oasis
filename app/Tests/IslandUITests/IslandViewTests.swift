import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct IslandViewTests {
    static let info = NowPlayingInfo(title: "Fire", artist: "Demo Artist", isPlaying: true, duration: 200, elapsed: 30)

    @MainActor
    @Test("Снимки острова во всех состояниях", arguments: [
        ("idle", Surface.idle), ("compact", .compact), ("peek", .peek),
        ("hover", .hover), ("expanded", .expanded), ("hud", .hud(.volume, level: 0.5)),
        ("nudge", .hoverNudge(from: .compact)),
    ])
    func snapshot(name: String, surface: Surface) throws {
        var model = IslandModel()
        model.surface = surface
        model.hasMedia = true
        let notch = CGSize(width: 186, height: 32)
        let view = IslandView(
            model: model,
            spec: IslandGeometry.spec(for: surface, hasMedia: true, notch: notch, calendarIndicatorWidth: IslandView.calendarIndicatorWidth),
            notchWidth: notch.width,
            nowPlaying: Self.info,
            onClick: {},
            onAction: { _ in })
        try Snapshot.write(view, size: IslandGeometry.windowSize, name: "island-\(name)")
    }
}
