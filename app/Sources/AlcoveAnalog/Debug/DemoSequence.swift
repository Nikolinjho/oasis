import Foundation
import IslandCore

/// Фиксированный прогон состояний на фейках для записи и сверки с эталоном.
/// Режим .alcove: эталон записан с поведением Alcove. Время шагов совпадает с capture/targets.json:
/// менять только вместе, DemoSequenceTests это проверяет
@MainActor
enum DemoSequence {
    /// Конфиг до первого запуска. Ставится только если пуст: второй прогон, начатый поверх первого
    /// (steps() вызывается заново, когда store.config уже .alcove), не должен затереть его своим
    private static var savedConfig: IslandMachine.Config?
    /// Какой прогон сейчас владеет восстановлением: у отменённого первого прогона onEnd срабатывает
    /// позже второго и не должен откатить конфиг, которым второй ещё пользуется
    private static var activeToken = 0

    /// Запускает сценарий и сам следит за откатом конфига — на обычном завершении и на отмене
    /// (DebugScript.run отменяет предыдущий прогон при любом новом отладочном действии или ссылке)
    @discardableResult
    static func run(store: IslandStore, after delay: Double = 0) -> Task<Void, Never> {
        activeToken += 1
        let token = activeToken
        return DebugScript.run(steps(store: store), after: delay, onEnd: { restore(store: store, token: token) })
    }

    static func steps(store: IslandStore) -> [DebugScript.Step] {
        [
            (at: 0.0, run: {
                if savedConfig == nil { savedConfig = store.config }
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
            (at: 16.0, run: {}),                                                 // даёт «уходу» просесть перед откатом конфига в onEnd
        ]
    }

    /// Откатывает конфиг, если этот прогон всё ещё последний (token совпадает с activeToken):
    /// у отменённого более ранним прогоном restore — no-op, конфиг остаётся за тем, кто ещё работает
    private static func restore(store: IslandStore, token: Int) {
        guard token == activeToken, let saved = savedConfig else { return }
        store.config = saved
        savedConfig = nil
    }

    /// Значение `--demo-after <секунды>` из аргументов запуска
    static func launchDelay(arguments: [String]) -> Double? {
        guard let index = arguments.firstIndex(of: "--demo-after"), index + 1 < arguments.count else { return nil }
        return Double(arguments[index + 1])
    }
}
