import IslandCore
import IslandSources
import IslandUI
import Observation
import SwiftUI

/// Держит модель острова и исполняет эффекты машины: анимации через withAnimation, таймеры через Task
@MainActor
@Observable
final class IslandStore {
    private(set) var model = IslandModel()
    private(set) var nowPlaying: NowPlayingInfo?
    var notch = CGSize(width: 186, height: 32)

    @ObservationIgnored var onCommand: (MediaCommand) -> Void = { _ in }
    @ObservationIgnored private var timers: [TimerID: Task<Void, Never>] = [:]

    var spec: IslandShapeSpec {
        IslandGeometry.spec(for: model.surface, hasMedia: model.hasMedia, notch: notch)
    }

    func send(_ event: IslandEvent) {
        var next = model
        let effects = IslandMachine.reduce(&next, event)

        var transition: IslandTransition?
        for case let .animate(t) in effects { transition = t }
        if let spring = transition.flatMap(IslandMotion.spring(for:)) {
            withAnimation(spring.animation) { model = next }
        } else {
            model = next
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
