import AppKit
import Foundation
import IslandCore

/// Будит CalendarSchedule на ближайшей границе и шлёт в store напоминания, старт и окно календаря.
/// Между границами не тикает: секунды в компакте обновляет TimelineView. Кроме таймера будят
/// смена системного времени и выход из сна: граница могла пройти, пока таймер стоял
@MainActor
final class CalendarClock {
    private let store: IslandStore
    private var agenda = DayAgenda.empty
    private var lastTick: Date
    /// Событие окна, отправленное в store: целиком, чтобы правка названия или конца внутри окна дошла до store
    private var live: CalendarEvent?
    private var timer: Task<Void, Never>?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(store: IslandStore, start: Date = Date()) {
        self.store = store
        lastTick = start
        let wake: [(NotificationCenter, Notification.Name)] = [
            (.default, .NSSystemClockDidChange),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
        ]
        observers = wake.map { center, name in
            (center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            })
        }
    }

    isolated deinit {
        timer?.cancel()
        for (center, token) in observers { center.removeObserver(token) }
    }

    func update(agenda: DayAgenda, now: Date = Date()) {
        self.agenda = agenda
        tick(now: now)
    }

    func tick(now: Date = Date()) {
        // окно раньше отметок: проснулись после начала — сначала компакт календаря, и только поверх него
        // calendarStarted откроет peek старта. В обратном порядке из формы выреза был бы только звук
        let live = CalendarSchedule.liveEvent(in: agenda, at: now)
        if live != self.live {
            self.live = live
            store.setCalendarLive(live)
        }
        for tick in CalendarSchedule.crossings(in: agenda, from: lastTick, to: now) {
            switch tick {
            case let .reminder(event, minutes):
                store.send(.alertArrived(.calendarReminder(CalendarReminder(
                    eventID: event.id, title: event.title, minutes: minutes, color: event.color))))
            case .started:
                store.send(.calendarStarted)
            }
        }
        lastTick = now
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
