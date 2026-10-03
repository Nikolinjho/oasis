import Foundation

/// Что произошло в календаре между двумя тиками часов
public enum CalendarTick: Equatable, Sendable {
  case reminder(CalendarEvent, minutes: Int)
  case started(CalendarEvent)
}

/// Время календаря (Alcove 1.7.9, 29.09): окно — за Time before event до начала (15 минут по умолчанию),
/// peek на старте. Напоминания за 15 и 5 минут — Before event starts, у Alcove по умолчанию выключен
public enum CalendarSchedule {
  public static let reminderMinutes = [15, 5]
  /// Окно календаря открывается за 15 минут до начала: Time before event по умолчанию (ui-inspection 1.9)
  public static let liveLead: TimeInterval = 15 * 60
  /// Отметку старше этого (Mac спал, таймер опоздал) уже не показываем
  public static let staleAfter: TimeInterval = 60

  /// Событие окна календаря. Сначала — среди уже начавшихся и ещё не закончившихся, то, что стартовало
  /// позже всех: событие внутри идущего забирает окно в момент своего старта, а не раньше — это отдельная
  /// проверка именно ради событий встык/пересечения, отдельно от простого «начнётся в ближайшие liveLead».
  /// Если ни одно не началось — ближайшее по старту предстоящее, чьё окно (start−liveLead) уже открыто.
  /// Поведение Alcove для событий встык (A 10:00–10:30, B 10:30…) вживую не проверяли — оценка.
  /// События по началу (DayAgenda.make), завтрашние после сегодняшних
  public static func liveEvent(in agenda: DayAgenda, at now: Date) -> CalendarEvent? {
    let list = events(agenda)
    let started: CalendarEvent? = list.last { (event: CalendarEvent) -> Bool in
      event.start <= now && now < event.end
    }
    if let started { return started }
    let upcoming: [CalendarEvent] = list.filter { (event: CalendarEvent) -> Bool in
      let windowOpensAt: Date = event.start.addingTimeInterval(-liveLead)
      return now < event.start && windowOpensAt <= now
    }
    return upcoming.min { (a: CalendarEvent, b: CalendarEvent) -> Bool in a.start < b.start }
  }

  public static func crossings(in agenda: DayAgenda, from previous: Date, to now: Date) -> [CalendarTick] {
    guard now > previous else { return [] }
    var ticks: [CalendarTick] = []
    for event in events(agenda) {
      for minutes in reminderMinutes where crossed(reminderMark(event, minutes), previous, now) {
        ticks.append(.reminder(event, minutes: minutes))
      }
      if crossed(event.start, previous, now) { ticks.append(.started(event)) }
    }
    return ticks
  }

  /// Следующая граница — ближайшая из напоминаний, окна T−15, старта и конца: по ней часы просыпаются.
  /// reminders — Before event starts: выключены — отметки напоминаний не будят часы зря
  public static func nextBoundary(in agenda: DayAgenda, after now: Date, reminders: Bool = true) -> Date? {
    events(agenda)
      .flatMap { event in
        (reminders ? reminderMinutes.map { reminderMark(event, $0) } : [])
          + [event.start.addingTimeInterval(-liveLead), event.start, event.end]
      }
      .filter { $0 > now }
      .min()
  }

  /// Сегодня и завтра: у события в начале суток (00:05) напоминание и окно наступают ещё накануне
  private static func events(_ agenda: DayAgenda) -> [CalendarEvent] {
    agenda.today + agenda.tomorrow
  }

  static func reminderMark(_ event: CalendarEvent, _ minutes: Int) -> Date {
    event.start.addingTimeInterval(-Double(minutes) * 60)
  }

  private static func crossed(_ mark: Date, _ previous: Date, _ now: Date) -> Bool {
    previous < mark && mark <= now && now.timeIntervalSince(mark) <= staleAfter
  }
}
