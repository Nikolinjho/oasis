import AppKit
import IslandCore

@MainActor
enum DebugMenu {
    static func items(store: IslandStore) -> [NSMenuItem] {
        var trackIndex = -1
        return [
            ClosureMenuItem("Fake Track") {
                trackIndex += 1
                store.apply(.newTrack(DemoTracks.all[trackIndex % DemoTracks.all.count]))
            },
            ClosureMenuItem("Fake Volume HUD") {
                store.send(.hudChanged(.volume, level: (Double.random(in: 0...1) * 16).rounded() / 16))
            },
            ClosureMenuItem("Clear Track") {
                store.apply(.cleared)
            },
        ]
    }
}
