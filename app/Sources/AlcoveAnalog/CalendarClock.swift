import Foundation
import IslandCore

/// Будит CalendarSchedule на ближайшей границе и шлёт в store напоминания, старт и окно календаря.
/// Между границами не тикает: секунды в компакте обновляет TimelineView
@MainActor
final class CalendarClock {
    private let store: IslandStore
    private var agenda = DayAgenda.empty
    private var lastTick: Date
    private var liveID: String?
    private var timer: Task<Void, Never>?

    init(store: IslandStore, start: Date = Date()) {
        self.store = store
        lastTick = start
    }

    func update(agenda: DayAgenda, now: Date = Date()) {
        self.agenda = agenda
        tick(now: now)
    }

    func tick(now: Date = Date()) {
        for tick in CalendarSchedule.crossings(in: agenda, from: lastTick, to: now) {
            switch tick {
            case let .reminder(event, minutes):
                store.send(.alertArrived(.calendarReminder(CalendarReminder(title: event.title, minutes: minutes, color: event.color))))
            case .started:
                store.send(.calendarStarted)
            }
        }
        lastTick = now
        let live = CalendarSchedule.liveEvent(in: agenda, at: now)
        if live?.id != liveID {
            liveID = live?.id
            store.setCalendarLive(live)
        }
        schedule(after: now)
    }

    /// До ближайшей границы, но не дольше 5 минут: agenda могла устареть, а часы — уйти после сна
    private func schedule(after now: Date) {
        timer?.cancel()
        let next = CalendarSchedule.nextBoundary(in: agenda, after: now) ?? now.addingTimeInterval(300)
        let delay = min(max(next.timeIntervalSince(now), 0.05), 300)
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
}
