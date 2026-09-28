import Foundation
import IslandCore
import IslandSources

/// Все отладочные действия по разделам. Новая поверхность приходит вместе со своим разделом или пунктом
@MainActor
enum DebugCatalog {
    static func sections(
        store: IslandStore, settings: AppSettings? = nil, sounds: SoundPlayer = SoundPlayer()
    ) -> [DebugSection] {
        let tracks = DemoTrackCursor()
        return [
            music(store, tracks),
            hud(store),
            calendar(store),
            battery(store),
            connectivity(store),
            sound(sounds),
            island(store),
            scenarios(store, tracks),
            timing(store, settings),
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
            // источник музыки на переднем плане без переключения приложений: для Hide while source app is active
            .action(DebugAction(id: "music.source-active", title: "Toggle Source App Active",
                                isOn: { store.model.sourceActive }) {
                store.send(.sourceActiveChanged(!store.model.sourceActive))
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

    private static func calendar(_ store: IslandStore) -> DebugSection {
        DebugSection(title: "Calendar", entries: [
            .action(DebugAction(id: "calendar.duo-event", title: "Duo With Fake Event") {
                let now = Date()
                store.pinDebugEvents([CalendarEvent(
                    id: "fake-event", title: "Fake Event",
                    start: now.addingTimeInterval(-300), end: now.addingTimeInterval(1500),
                    isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35))])
                store.send(.clicked)
            }),
            .action(DebugAction(id: "calendar.duo-meet", title: "Duo With Fake Meet Call") {
                let now = Date()
                store.pinDebugEvents([CalendarEvent(
                    id: "fake-meet", title: "Fake Call", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(1740),
                    isAllDay: false, color: RGB(red: 0.2, green: 0.5, blue: 1),
                    notes: "Join: https://meet.google.com/abc-defg-hij")])
                store.send(.clicked)
            }),
            .action(DebugAction(id: "calendar.duo-empty", title: "Duo Empty Day") {
                store.pinDebugEvents([])
                store.send(.clicked)
            }),
            // галочка показывает, что реальный календарь сейчас активен: полезно после duo-event/duo-empty
            .action(DebugAction(
                id: "calendar.real", title: "Use Real Calendar",
                isOn: { !store.isDebugAgendaPinned }
            ) {
                store.unpinDebugEvents()
            }),
            .separator,
            .action(DebugAction(id: "calendar.live", title: "Live: Fake Event in 45 s") {
                let start = Date().addingTimeInterval(45)
                store.setCalendarLive(CalendarEvent(
                    id: "fake-live", title: "Fake Event", start: start, end: start.addingTimeInterval(300),
                    isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35)))
            }),
            .action(DebugAction(id: "calendar.start", title: "Event Starts Now") {
                let now = Date()
                store.setCalendarLive(CalendarEvent(
                    id: "fake-start", title: "Fake Event", start: now, end: now.addingTimeInterval(300),
                    isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35)))
                store.send(.calendarStarted)
            }),
            .action(DebugAction(id: "calendar.live-off", title: "Live Off") { store.setCalendarLive(nil) }),
            .action(DebugAction(id: "calendar.remind", title: "Reminder in 2 s (15 min before)") {
                // событие через 15 мин 2 с: часы получат повестку через onAgendaChange и сами пересекут отметку T−15.
                // Закреплённая повестка, как у calendar.duo-event: живой источник её не перезапишет, снимает calendar.real
                let start = Date().addingTimeInterval(15 * 60 + 2)
                store.pinDebugEvents([CalendarEvent(
                    id: "fake-remind", title: "Fake Call", start: start, end: start.addingTimeInterval(1800),
                    isAllDay: false, color: RGB(red: 0.2, green: 0.5, blue: 1))])
            }),
            .action(DebugAction(id: "calendar.menu-event", title: "Meet Call in 8 min (menu items)") {
                // как на скрине меню Alcove: событие через 8 минут, в меню Join, Open in Calendar, Dismiss Event.
                // Закреплённая повестка: часы получат её через onAgendaChange, снимает calendar.real
                let start = Date().addingTimeInterval(8 * 60)
                store.pinDebugEvents([CalendarEvent(
                    id: "fake-menu@\(start.timeIntervalSince1970)", title: "Fake Call", start: start,
                    end: start.addingTimeInterval(1800), isAllDay: false, color: RGB(red: 0.2, green: 0.5, blue: 1),
                    notes: "Join: https://meet.google.com/abc-defg-hij")])
            }),
        ])
    }

    private static func battery(_ store: IslandStore) -> DebugSection {
        DebugSection(title: "Battery", entries: [
            .action(DebugAction(id: "battery.charging-51", title: "Charging 51%") {
                store.send(.alertArrived(.charging(level: 0.51)))
            }),
            .action(DebugAction(id: "battery.charging-100", title: "Charging 100%") {
                store.send(.alertArrived(.charging(level: 1)))
            }),
            .separator,
            .action(DebugAction(id: "battery.low", title: "Low Battery 10%") {
                store.send(.alertArrived(.lowBattery(level: 0.1)))
            }),
            .action(DebugAction(id: "battery.low-power", title: "Low Power Mode") {
                store.send(.alertArrived(.lowPower(level: 0.4)))
            }),
            .separator,
            // очередь: HUD держит все три, после него — по приоритету Low Battery, Low Power, Charging
            .action(DebugAction(id: "battery.queue", title: "HUD + Three Alerts (Queue)") {
                store.send(.hudChanged(.volume, level: 0.5))
                store.send(.alertArrived(.charging(level: 0.8)))
                store.send(.alertArrived(.lowPower(level: 0.4)))
                store.send(.alertArrived(.lowBattery(level: 0.1)))
            }),
        ])
    }

    private static func connectivity(_ store: IslandStore) -> DebugSection {
        DebugSection(title: "Connectivity", entries: [
            .action(DebugAction(id: "airpods.connected", title: "Fake AirPods Pro 100%") {
                store.send(.alertArrived(.airpods(AirPodsInfo(name: "Fake AirPods Pro", battery: 1))))
            }),
            .action(DebugAction(id: "airpods.low", title: "Fake AirPods 15%") {
                store.send(.alertArrived(.airpods(AirPodsInfo(name: "Fake AirPods", battery: 0.15))))
            }),
            .action(DebugAction(id: "airpods.low-warning", title: "Fake AirPods Low Battery Warning 15%") {
                store.send(.alertArrived(.airpods(AirPodsInfo(name: "Fake AirPods Pro", battery: 0.15, model: .pro, isLowBattery: true))))
            }),
            .separator,
            // как на записи Alcove: календарь → сжатие → AirPods на 5 с → обратно календарь
            .action(DebugAction(id: "scenario.calendar-airpods", title: "Calendar → AirPods → Calendar") {
                let start = Date().addingTimeInterval(50)
                DebugScript.run([
                    (at: 0, run: {
                        store.setCalendarLive(CalendarEvent(
                            id: "fake-live", title: "Fake Event", start: start, end: start.addingTimeInterval(300),
                            isAllDay: false, color: RGB(red: 0.35, green: 0.85, blue: 0.35)))
                    }),
                    (at: 1.5, run: { store.send(.alertArrived(.airpods(AirPodsInfo(name: "Fake AirPods Pro", battery: 1)))) }),
                ])
            }),
        ])
    }

    private static func sound(_ sounds: SoundPlayer) -> DebugSection {
        DebugSection(title: "Sounds", entries: IslandSound.allCases.map { sound in
            .action(DebugAction(id: "sound.\(sound.rawValue)", title: "Play \(sound.rawValue)") { sounds.play(sound) })
        })
    }

    private static func island(_ store: IslandStore) -> DebugSection {
        DebugSection(title: "Island", entries: [
            .action(DebugAction(id: "island.hover", title: "Hover") { store.send(.hoverEntered) }),
            .action(DebugAction(id: "island.leave", title: "Leave") { store.send(.hoverExited) }),
            .action(DebugAction(id: "island.open", title: "Open") { store.send(.clicked) }),
            .action(DebugAction(id: "island.close", title: "Close") { store.send(.clickedOutside) }),
            .action(DebugAction(id: "island.cycle", title: "Cycle Expanded View") { store.send(.expandedViewCycled) }),
            .separator,
            // синтетический свайп двумя пальцами по раскрытому (Task 9): те же фазы, что шлёт монитор scrollWheel.
            // Шаги по 30 мс, travel — сжатие/растяжение в pt, hold — пауза перед отпусканием для скриншота
            swipe(store, id: "island.swipe-down", title: "Swipe Down (Cycle View)", travel: 30, hold: 0.8),
            swipe(store, id: "island.swipe-down-hold", title: "Swipe Down, Release Before Threshold", travel: 15, hold: 1.0),
            swipe(store, id: "island.swipe-up-hold", title: "Swipe Up, Release Before Threshold", travel: -15, hold: 1.0),
            swipe(store, id: "island.swipe-up", title: "Swipe Up (Close)", travel: -30, hold: 0.3),
            .separator,
            .action(DebugAction(id: "island.morph-hud", title: "Morph Expanded → HUD") {
                DebugScript.run([
                    (at: 0, run: { store.send(.clicked) }),
                    (at: 1.0, run: { store.send(.hudChanged(.volume, level: 0.5)) }),
                ])
            }),
        ])
    }

    /// Свайп над раскрытым без трекпада: открывает остров, если он закрыт, и прогоняет жест через store.swipe
    private static func swipe(_ store: IslandStore, id: String, title: String, travel: CGFloat, hold: Double) -> DebugEntry {
        .action(DebugAction(id: id, title: title) {
            let steps = 10
            let dy = travel / SwipeTracker.pointsPerDelta / CGFloat(steps)
            let opens = store.model.surface != .expanded
            let start = opens ? 1.0 : 0
            var script: [DebugScript.Step] = []
            if opens { script.append((at: 0, run: { store.send(.clicked) })) }
            script.append((at: start, run: { store.swipe(.began, dy: 0) }))
            for i in 1...steps {
                script.append((at: start + Double(i) * 0.03, run: { store.swipe(.changed, dy: dy) }))
            }
            script.append((at: start + Double(steps) * 0.03 + hold, run: { store.swipe(.ended, dy: 0) }))
            DebugScript.run(script)
        })
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

    private static func timing(_ store: IslandStore, _ settings: AppSettings?) -> DebugSection {
        func mode(_ id: String, _ title: String, _ scale: Double) -> DebugEntry {
            .action(DebugAction(id: id, title: title, isOn: { store.config.timeScale == scale }) {
                store.config.timeScale = scale
            })
        }
        return DebugSection(title: "Timing", entries: [
            mode("timing.alcove", "Alcove Timing ×1.0", 1),
            mode("timing.user", "User Timing ×1.18", IslandMachine.Config.user.timeScale),
            mode("timing.slow", "Slow Animations ×5", 5),
            .separator,
            // General → Expand on hover: тот же переключатель, что в окне настроек. Идёт через AppSettings,
            // а не в store.config напрямую — иначе окно настроек не знает о переключении и следующее
            // изменение там же тихо откатывает его обратно
            .action(DebugAction(
                id: "settings.expand-on-hover", title: "Expand on Hover",
                isOn: { settings?.expandOnHover ?? store.config.expandsOnHover }
            ) {
                if let settings {
                    settings.expandOnHover.toggle()
                } else {
                    store.config.expandsOnHover.toggle()
                }
            }),
        ])
    }
}
