import AppKit
import IslandCore
import IslandSources
import IslandUI
import Observation
import SwiftUI

/// Держит модель острова и исполняет эффекты машины: анимации через withAnimation, таймеры через Task
@MainActor
@Observable
final class IslandStore {
    private(set) var model: IslandModel
    private(set) var nowPlaying: NowPlayingInfo?
    var notch = CGSize(width: 186, height: 32)

    @ObservationIgnored var onAction: (PlayerAction) -> Void = { _ in }
    /// Вызывается после смены surface: окно пересчитывает hit-testing, даже если мышь стоит на месте
    @ObservationIgnored var onSurfaceChange: () -> Void = {}
    @ObservationIgnored private var timers: [TimerID: Task<Void, Never>] = [:]

    init(config: IslandMachine.Config = .user) {
        model = IslandModel(config: config)
    }

    /// Режим машины. Demo-прогон переключает на .alcove: эталон сверки записан с поведением Alcove
    var config: IslandMachine.Config {
        get { model.config }
        set { model.config = newValue }
    }

    var spec: IslandShapeSpec {
        IslandGeometry.spec(for: model.surface, hasMedia: model.hasMedia, notch: notch)
    }

    func send(_ event: IslandEvent) {
        var next = model
        let previous = model.surface
        let effects = IslandMachine.reduce(&next, event)

        var transition: IslandTransition?
        for case let .animate(t) in effects { transition = t }
        if let spring = transition.flatMap({ IslandMotion.spring(for: $0, timeScale: next.config.timeScale) }) {
            withAnimation(spring.animation) { model = next }
        } else {
            model = next
        }
        if transition?.opensByHover == true {
            // .generic, а не .levelChange: levelChange — щелчок шага значения (слайдер, громкость),
            // а раскрытие острова — обычное подтверждение действия. Трекпад отдаёт отклик,
            // только если на нём лежит палец, от мыши его нет
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }

        for effect in effects {
            switch effect {
            case .animate:
                break
            case let .schedule(id, delay):
                timers[id]?.cancel()
                timers[id] = Task { [weak self] in
                    try? await Task.sleep(for: delay)
                    guard !Task.isCancelled else { return }
                    self?.timers[id] = nil
                    self?.send(.timerFired(id))
                }
            case let .cancel(id):
                timers[id]?.cancel()
                timers[id] = nil
            }
        }
        // после эффектов: вложенный send из колбэка не перемешается с таймерами этого события
        if model.surface != previous { onSurfaceChange() }
    }

    func apply(_ change: NowPlayingChange) {
        switch change {
        case let .newTrack(info):
            nowPlaying = info
            send(.trackChanged)
        case let .updated(info):
            nowPlaying = info
        case .cleared:
            nowPlaying = nil
            send(.mediaCleared)
        }
    }
}
