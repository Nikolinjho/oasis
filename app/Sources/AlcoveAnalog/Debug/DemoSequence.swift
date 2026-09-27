import Foundation
import IslandCore

/// Фиксированный прогон состояний на фейках для записи и сверки с эталоном.
/// Режим .alcove: эталон записан с поведением Alcove. Время шагов совпадает с capture/targets.json:
/// менять только вместе, DemoSequenceTests это проверяет
@MainActor
enum DemoSequence {
    static func steps(store: IslandStore) -> [DebugScript.Step] {
        let saved = store.config
        return [
            (at: 0.0, run: {
                store.config = .alcove
                store.apply(.cleared)
            }),
            (at: 1.0, run: { store.apply(.newTrack(DemoTracks.all[0])) }),        // компакт: появление
            (at: 2.5, run: { store.apply(.newTrack(DemoTracks.all[1])) }),        // peek, через 2 с обратно в компакт
            (at: 5.5, run: { store.send(.hudChanged(.volume, level: 0.5)) }),     // сжатие → HUD → сжатие → компакт
            (at: 9.5, run: { store.send(.hoverEntered) }),                       // компакт → hover 190×73
            (at: 11.0, run: { store.send(.clicked) }),                           // hover → раскрытый
            (at: 13.0, run: { store.send(.clickedOutside) }),                    // раскрытый → компакт
            (at: 14.5, run: { store.apply(.cleared) }),                          // компакт: уход
            (at: 16.0, run: { store.config = saved }),
        ]
    }

    /// Значение `--demo-after <секунды>` из аргументов запуска
    static func launchDelay(arguments: [String]) -> Double? {
        guard let index = arguments.firstIndex(of: "--demo-after"), index + 1 < arguments.count else { return nil }
        return Double(arguments[index + 1])
    }
}
