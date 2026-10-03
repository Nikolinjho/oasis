import Foundation

/// Что произошло в календаре между двумя тиками часов
public enum CalendarTick: Equatable, Sendable {
  case reminder(CalendarEvent, minutes: Int)
  case started(CalendarEvent)
}

/// Время календаря (Alcove 1.7.9, 29.09): окно — за Time before event до начала (lead, 15 минут по умолчанию),
/// peek на старте. Напоминание Before event starts — в начале окна, у Alcove по умолчанию выключено
public enum CalendarSchedule {
  /// Time before event по умолчанию (ui-inspection 1.9)
  public static let defaultLead: TimeInterval = 15 * 60
  /// Отметку старше этого (Mac спал, таймер опоздал) уже не показываем
  public static let staleAfter: TimeInterval = 60

  /// Событие окна календаря. Сначала — среди уже начавшихся и ещё не закончившихся, то, что стартовало
  /// позже всех: событие внутри идущего забирает окно в момент своего старта, а не раньше — это отдельная
  /// проверка именно ради событий встык/пересечения, отдельно от простого «начнётся в ближайшие lead».
  /// Если ни одно не началось — ближайшее по старту предстоящее, чьё окно (start−lead) уже открыто.
  /// Поведение Alcove для событий встык (A 10:00–10:30, B 10:30…) вживую не проверяли — оценка.
  /// События по началу (DayAgenda.make), завтрашние после сегодняшних
  public static func liveEvent(in agenda: DayAgenda, at now: Date, lead: TimeInterval = defaultLead) -> CalendarEvent? {
    let list = events(agenda)
    let started: CalendarEvent? = list.last { (event: CalendarEvent) -> Bool in
      event.start <= now && now < event.end
    }
    if let started { return started }
    let upcoming: [CalendarEvent] = list.filter { (event: CalendarEvent) -> Bool in
      let windowOpensAt: Date = event.start.addingTimeInterval(-lead)
      return now < event.start && windowOpensAt <= now
    }
    return upcoming.min { (a: CalendarEvent, b: CalendarEvent) -> Bool in a.start < b.start }
  }

  /// Напоминание — в начале окна (T − lead), за столько минут, сколько Time before event
  public static func crossings(
    in agenda: DayAgenda, from previous: Date, to now: Date, lead: TimeInterval = defaultLead
  ) -> [CalendarTick] {
    guard now > previous else { return [] }
    var ticks: [CalendarTick] = []
    for event in events(agenda) {
      if crossed(event.start.addingTimeInterval(-lead), previous, now) {
        ticks.append(.reminder(event, minutes: Int((lead / 60).rounded())))
      }
      if crossed(event.start, previous, now) { ticks.append(.started(event)) }
    }
    return ticks
  }

  /// Следующая граница — ближайшая из окна T − lead (оно же напоминание), старта и конца: по ней часы просыпаются.
  /// extra — свои отметки события (Disable activity during events: конец peek на старте)
  public static func nextBoundary(
    in agenda: DayAgenda, after now: Date, lead: TimeInterval = defaultLead,
    extra: (CalendarEvent) -> [Date] = { _ in [] }
  ) -> Date? {
    events(agenda)
      .flatMap { event in [event.start.addingTimeInterval(-lead), event.start, event.end] + extra(event) }
      .filter { $0 > now }
      .min()
  }

  /// Сегодня и завтра: у события в начале суток (00:05) напоминание и окно наступают ещё накануне
  private static func events(_ agenda: DayAgenda) -> [CalendarEvent] {
    agenda.today + agenda.tomorrow
  }

  private static func crossed(_ mark: Date, _ previous: Date, _ now: Date) -> Bool {
    previous < mark && mark <= now && now.timeIntervalSince(mark) <= staleAfter
  }
}
