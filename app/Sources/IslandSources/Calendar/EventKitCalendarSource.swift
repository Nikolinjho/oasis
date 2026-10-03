import CoreGraphics
import EventKit
import Foundation
import IslandCore

/// События из EventKit: месяц целиком и неделя вперёд (range). Пересчёт на изменение базы календарей, на смену дня и раз в 5 минут:
/// agenda зависит от текущего времени, закончившееся событие уходит из Duo не позже чем через 5 минут
@MainActor
public final class EventKitCalendarSource {
  public let changes: AsyncStream<[CalendarEvent]>
  private let continuation: AsyncStream<[CalendarEvent]>.Continuation
  private let store = EKEventStore()
  private var observers: [NSObjectProtocol] = []
  private var timer: Timer?
  private let log = SourceLog.logger("calendar")

  public init() {
    (changes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
  }

  /// Запрашивает полный доступ. Без него остров работает без календаря: Duo показывает пустой день
  public func start() {
    store.requestFullAccessToEvents { [weak self] granted, error in
      Task { @MainActor in
        guard let self else { return }
        guard granted else {
          self.log.error("calendar access denied: \(error?.localizedDescription ?? "no error", privacy: .public)")
          return
        }
        self.reload()
        self.observe()
      }
    }
  }

  public func reload() {
    let range = Self.range(now: Date())
    let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
    let events = store.events(matching: predicate).map(Self.event)
    log.info("calendar events \(events.count)")
    continuation.yield(events)
  }

  /// Сетке месяца нужен весь месяц (индикаторы и у прошедших дней), правой колонке календарного вида —
  /// ближайший день с событиями в пределах 7 дней: с 1-го числа до конца месяца или 8-го дня вперёд, что позже
  nonisolated static func range(now: Date, calendar: Calendar = .current) -> DateInterval {
    let today = calendar.startOfDay(for: now)
    let month = calendar.dateInterval(of: .month, for: today) ?? DateInterval(start: today, duration: 0)
    let week = calendar.date(byAdding: .day, value: 8, to: today) ?? today
    return DateInterval(start: month.start, end: max(month.end, week))
  }

  private func observe() {
    let center = NotificationCenter.default
    for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.reload() }
        })
    }
    timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.reload() }
    }
  }

  nonisolated static func event(_ event: EKEvent) -> CalendarEvent {
    CalendarEvent(
      id: "\(event.eventIdentifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSince1970)",
      title: event.title ?? "",
      start: event.startDate,
      end: event.endDate,
      isAllDay: event.isAllDay,
      color: rgb(event.calendar?.cgColor),
      url: event.url,
      location: event.location,
      notes: event.notes,
      calendarID: event.calendar?.calendarIdentifier)
  }

  /// Календари для списка Calendars на странице настроек: свой store, доступ к событиям уже выдан источнику.
  /// Порядок — по аккаунту, внутри по названию
  public static func calendars() -> [CalendarInfo] {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
    return EKEventStore().calendars(for: .event)
      .sorted { ($0.source?.title ?? "", $0.title) < ($1.source?.title ?? "", $1.title) }
      .map { calendar in
        CalendarInfo(
          id: calendar.calendarIdentifier, title: calendar.title, color: rgb(calendar.cgColor),
          kind: calendar.type == .birthday ? .birthdays : calendar.type == .subscription ? .subscription : .regular)
      }
  }

  /// Цвет календаря в sRGB. Без цвета — красный календарный, как иконка Calendar
  nonisolated static func rgb(_ color: CGColor?) -> RGB {
    guard let color, let srgb = CGColorSpace(name: CGColorSpace.sRGB),
      let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
      components.count >= 3
    else { return RGB(red: 1, green: 0.27, blue: 0.23) }
    return RGB(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2]))
  }
}
