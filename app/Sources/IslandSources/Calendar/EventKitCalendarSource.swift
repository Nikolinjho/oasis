import CoreGraphics
import EventKit
import Foundation
import IslandCore

/// События сегодня и завтра из EventKit. Пересчёт на изменение базы календарей, на смену дня и раз в 5 минут:
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
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let end = calendar.date(byAdding: .day, value: 2, to: start)!
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = store.events(matching: predicate).map(Self.event)
    log.info("calendar events \(events.count)")
    continuation.yield(events)
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
      notes: event.notes)
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
