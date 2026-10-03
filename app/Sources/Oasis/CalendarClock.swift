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
  /// Dismiss Event: id отклонённых событий. Их нет ни в окне, ни в напоминаниях, ни в границах таймера, ни в меню
  /// Store получает их для стопки Duo
  private var dismissed: Set<String> = [] {
    didSet { if dismissed != oldValue { store.dismissedEvents = dismissed } }
  }
  private var timer: Task<Void, Never>?
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []
  /// Before event starts: напоминания-peek за 15 и 5 минут. У Alcove по умолчанию выключено (ui-inspection 1.9),
  /// страницы Calendar в P2 нет — включается только кодом и в тестах
  private let remindsBeforeStart: Bool

  init(store: IslandStore, start: Date = Date(), remindsBeforeStart: Bool = false) {
    self.store = store
    self.remindsBeforeStart = remindsBeforeStart
    lastTick = start
    let wake: [(NotificationCenter, Notification.Name)] = [
      (.default, .NSSystemClockDidChange),
      (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
    ]
    observers = wake.map { center, name in
      (
        center,
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.tick() }
        }
      )
    }
  }

  isolated deinit {
    timer?.cancel()
    for (center, token) in observers { center.removeObserver(token) }
  }

  func update(agenda: DayAgenda, now: Date = Date()) {
    self.agenda = agenda
    // отклонённые, которых уже нет в agenda, забываются. Завтрашние тоже в счёт: в полночь событие
    // переезжает из tomorrow в today с тем же id и должно остаться отклонённым
    dismissed.formIntersection((agenda.today + agenda.tomorrow).map(\.id))
    tick(now: now)
  }

  func tick(now: Date = Date()) {
    // окно раньше отметок: проснулись после начала — сначала компакт календаря, и только поверх него
    // calendarStarted откроет peek старта. В обратном порядке из формы выреза был бы только звук
    let live = CalendarSchedule.liveEvent(in: visible, at: now)
    if live != self.live {
      self.live = live
      store.setCalendarLive(live)
    }
    // старт — не больше одного за тик: у событий с общим началом peek один, и звук не играет дважды
    var started = false
    for tick in CalendarSchedule.crossings(in: visible, from: lastTick, to: now) {
      switch tick {
      case .reminder(let event, let minutes):
        guard remindsBeforeStart else { continue }
        store.send(
          .alertArrived(
            .calendarReminder(
              CalendarReminder(
                eventID: event.id, title: event.title, minutes: minutes, color: event.color))))
      case .started where !started:
        started = true
        store.send(.calendarStarted)
      case .started:
        break
      }
    }
    lastTick = now
    schedule(after: now)
  }

  /// Dismiss Event: событие уходит из компакта, напоминаний и меню, пока оно есть в agenda
  /// Напоминания события тоже уходят: ждущие в очереди, показанное (сразу) и то, к которому идёт сжатие
  func dismiss(_ id: String, now: Date = Date()) {
    dismissed.insert(id)
    store.send(.alertRetracted(.calendarReminder(eventID: id)))
    tick(now: now)
  }

  /// Пункты события для меню menu bar. Окно календаря открыто — событие компакта (начавшееся позже всех), иначе
  /// самое раннее из T−15…конец. Отступление от «самое раннее» плана намеренное: при пересечении (A 10:00–11:00,
  /// B с 10:30) Join и Dismiss должны относиться к B, которое показывает остров, а не к A
  func menuModel(now: Date = Date()) -> CalendarMenuModel? {
    if let live = CalendarSchedule.liveEvent(in: visible, at: now) {
      return CalendarMenuModel(event: live, meeting: MeetingLink.find(in: live))
    }
    return CalendarMenuModel.make(agenda: agenda, now: now, dismissed: dismissed)
  }

  /// События без отклонённых: по ним считаются напоминания, старт, окно календаря и граница таймера
  private var visible: DayAgenda {
    DayAgenda(
      today: agenda.today.filter { !dismissed.contains($0.id) },
      tomorrow: agenda.tomorrow.filter { !dismissed.contains($0.id) })
  }

  /// До ближайшей границы, но не дольше 5 минут: agenda могла устареть, а часы — уйти после сна
  private func schedule(after now: Date) {
    timer?.cancel()
    let next = CalendarSchedule.nextBoundary(in: visible, after: now) ?? now.addingTimeInterval(300)
    let delay = min(max(next.timeIntervalSince(now), 0.05), 300)
    timer = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      self?.tick()
    }
  }
}
