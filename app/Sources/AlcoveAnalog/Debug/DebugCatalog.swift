import Foundation
import IslandCore
import IslandSources

/// Все отладочные действия по разделам. Новая поверхность приходит вместе со своим разделом или пунктом
@MainActor
enum DebugCatalog {
    static func sections(store: IslandStore) -> [DebugSection] {
        let tracks = DemoTrackCursor()
        return [
            music(store, tracks),
            hud(store),
            island(store),
            scenarios(store, tracks),
            timing(store),
        ]
    }

    private static func music(_ store: IslandStore, _ tracks: DemoTrackCursor) -> DebugSection {
        DebugSection(title: "Music", entries: [
            .action(DebugAction(id: "music.next", title: "Next Fake Track") {
                store.apply(.newTrack(tracks.next()))
            }),
            .action(DebugAction(id: "music.no-artwork", title: "Fake Track Without Artwork") {
                store.apply(.newTrack(DemoTracks.withoutArtwork))
            }),
            .action(DebugAction(id: "music.toggle", title: "Toggle Play/Pause") {
                guard var info = store.nowPlaying else { return }
                let now = Date()
                info.elapsed = info.position(at: now)
                info.elapsedAt = now
                info.isPlaying.toggle()
                store.apply(.updated(info))
            }),
            // повторный peek текущего трека: без трека действия нет
            .action(DebugAction(id: "music.peek", title: "Peek Now") {
                guard let info = store.nowPlaying else { return }
                store.apply(.newTrack(info))
            }),
            .separator,
            .action(DebugAction(id: "music.clear", title: "Clear Track") { store.apply(.cleared) }),
        ])
    }

    private static func hud(_ store: IslandStore) -> DebugSection {
        func level(_ kind: HUDKind, _ name: String, _ percent: Int) -> DebugEntry {
            .action(DebugAction(id: "hud.\(name.lowercased()).\(percent)", title: "\(name) \(percent)%") {
                store.send(.hudChanged(kind, level: Double(percent) / 100))
            })
        }
        let series = DebugAction(id: "hud.sound.series", title: "Sound ×5 in a Row") {
            // серия нажатий клавиши: HUD продлевается, полоска растёт шагами 1/16
            DebugScript.run((0..<5).map { i in
                (at: Double(i) * 0.15, run: { store.send(.hudChanged(.volume, level: 0.25 + Double(i) / 16)) })
            })
        }
        return DebugSection(title: "HUD", entries: [
            level(.volume, "Sound", 0), level(.volume, "Sound", 50), level(.volume, "Sound", 100),
            .separator,
            level(.brightness, "Display", 0), level(.brightness, "Display", 50), level(.brightness, "Display", 100),
            .separator,
            .action(series),
        ])
    }

    private static func island(_ store: IslandStore) -> DebugSection {
        DebugSection(title: "Island", entries: [
            .action(DebugAction(id: "island.hover", title: "Hover") { store.send(.hoverEntered) }),
            .action(DebugAction(id: "island.leave", title: "Leave") { store.send(.hoverExited) }),
            .action(DebugAction(id: "island.open", title: "Open") { store.send(.clicked) }),
            .action(DebugAction(id: "island.close", title: "Close") { store.send(.clickedOutside) }),
            .separator,
            .action(DebugAction(id: "island.morph-hud", title: "Morph Expanded → HUD") {
                DebugScript.run([
                    (at: 0, run: { store.send(.clicked) }),
                    (at: 1.0, run: { store.send(.hudChanged(.volume, level: 0.5)) }),
                ])
            }),
        ])
    }

    private static func scenarios(_ store: IslandStore, _ tracks: DemoTrackCursor) -> DebugSection {
        DebugSection(title: "Scenarios", entries: [
            .action(DebugAction(id: "demo.run", title: "Demo Sequence (Alcove Mode)") {
                DemoSequence.run(store: store)
            }),
            .separator,
            .action(DebugAction(id: "scenario.compact-hud", title: "Compact → HUD → Compact") {
                DebugScript.run([
                    (at: 0, run: { store.apply(.newTrack(tracks.next())) }),
                    (at: 1.5, run: { store.send(.hudChanged(.volume, level: 0.5)) }),
                ])
            }),
        ])
    }

    private static func timing(_ store: IslandStore) -> DebugSection {
        func mode(_ id: String, _ title: String, _ scale: Double) -> DebugEntry {
            .action(DebugAction(id: id, title: title, isOn: { store.config.timeScale == scale }) {
                store.config.timeScale = scale
            })
        }
        return DebugSection(title: "Timing", entries: [
            mode("timing.alcove", "Alcove Timing ×1.0", 1),
            mode("timing.user", "User Timing ×1.18", IslandMachine.Config.user.timeScale),
            mode("timing.slow", "Slow Animations ×5", 5),
        ])
    }
}
