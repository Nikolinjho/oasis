import Foundation

/// Событие календаря в том виде, в каком его показывает остров
public struct CalendarEvent: Equatable, Sendable, Identifiable {
  /// eventIdentifier плюс начало: у повторяющихся событий eventIdentifier общий
  public var id: String
  public var title: String
  public var start: Date
  public var end: Date
  public var isAllDay: Bool
  /// Цвет календаря: полоска и текст карточки события
  public var color: RGB
  /// Откуда ищется ссылка на созвон (P1, Join)
  public var url: URL?
  public var location: String?
  public var notes: String?
  /// calendarIdentifier календаря EventKit: по нему страница Calendar выключает календари и выбирает режим.
  /// У отладочных событий nil — их фильтр пропускает всегда
  public var calendarID: String?

  public init(
    id: String, title: String, start: Date, end: Date, isAllDay: Bool, color: RGB,
    url: URL? = nil, location: String? = nil, notes: String? = nil, calendarID: String? = nil
  ) {
    self.id = id
    self.title = title
    self.start = start
    self.end = end
    self.isAllDay = isAllDay
    self.color = color
    self.url = url
    self.location = location
    self.notes = notes
    self.calendarID = calendarID
  }
}

/// События сегодня и завтра для Duo и календарного вида
public struct DayAgenda: Equatable, Sendable {
  /// Не закончившиеся события сегодня, по началу. Весь день не входит: у него нет времени начала
  public var today: [CalendarEvent]
  /// События завтра, по началу, без событий на весь день
  public var tomorrow: [CalendarEvent]

  public static let empty = DayAgenda(today: [], tomorrow: [])

  public init(today: [CalendarEvent], tomorrow: [CalendarEvent]) {
    self.today = today
    self.tomorrow = tomorrow
  }

  public static func make(events: [CalendarEvent], now: Date, calendar: Calendar = .current) -> DayAgenda {
    let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    let startOfDayAfter = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow)!
    let timed =
      events
      .filter { !$0.isAllDay }
      .sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    return DayAgenda(
      today: timed.filter { $0.end > now && $0.start < startOfTomorrow },
      tomorrow: timed.filter { $0.start >= startOfTomorrow && $0.start < startOfDayAfter })
  }

  /// Идущее или ближайшее событие сегодня: его карточку показывает Duo.
  /// Считается от момента показа: agenda могла собраться несколько минут назад.
  /// live — событие открытого окна календаря (CalendarSchedule.liveEvent без отклонённых): при пересечении
  /// событий карточка и Join относятся к тому же событию, что компакт и меню, а не к первому не закончившемуся
  public func current(at now: Date, live: CalendarEvent? = nil) -> CalendarEvent? {
    // событие окна уже кончилось, а store ещё не узнал (TimelineView тикает раньше часов): прежнее правило.
    // Событие календаря Live Activity в повестку раскрытого не попало — и карточкой Duo не становится.
    // У отладочного события календаря нет: его повестки может и не быть
    if let live, live.end > now, live.calendarID == nil || (today + tomorrow).contains(where: { $0.id == live.id }) {
      return live
    }
    return today.first { $0.end > now }
  }

  /// Карточки Duo стопкой (Alcove 1.7.9, 29.09): первым — то же событие, что current, за ним сегодняшние,
  /// которые начнутся не раньше него. Идущие рядом с live, но начавшиеся раньше, не показываем: карточка
  /// и Join сверху должны совпадать с компактом.
  /// `>=` вместо `>`: одновременная встреча (тот же start, что у первой карточки) не должна пропадать.
  /// dismissed — отклонённые через Dismiss Event: их нет в стопке, как нет в компакте и меню
  public func upcoming(at now: Date, live: CalendarEvent? = nil, dismissed: Set<String> = []) -> [CalendarEvent] {
    let shown = dismissed.isEmpty ? self : DayAgenda(today: today.filter { !dismissed.contains($0.id) }, tomorrow: tomorrow)
    guard let first = shown.current(at: now, live: live) else { return [] }
    return [first] + shown.today.filter { $0.id != first.id && $0.end > now && $0.start >= first.start }
  }
}
