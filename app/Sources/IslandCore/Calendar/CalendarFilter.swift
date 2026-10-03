/// Где показываются события календаря: меню режима в списке Calendars (ui-inspection 1.9)
public enum CalendarDisplayMode: String, CaseIterable, Sendable {
  /// И live-активность (компакт, peek, напоминания), и раскрытый остров
  case both
  /// Только компакт, peek и напоминания
  case liveActivity
  /// Только раскрытый: Duo, календарный вид, меню
  case expandedView

  public var title: String {
    switch self {
    case .both: "Both"
    case .liveActivity: "Live Activity"
    case .expandedView: "Expanded View"
    }
  }

  var showsLive: Bool { self != .expandedView }
  var showsExpanded: Bool { self != .liveActivity }
}

/// Страница Calendar: главный тумблер, выключенные календари и режимы по calendarIdentifier.
/// Новый календарь — включён, Both. Событие без calendarID (отладка) проходит всегда
public struct CalendarFilter: Equatable, Sendable {
  public var isEnabled: Bool
  public var excluded: Set<String>
  public var modes: [String: CalendarDisplayMode]

  public init(isEnabled: Bool = true, excluded: Set<String> = [], modes: [String: CalendarDisplayMode] = [:]) {
    self.isEnabled = isEnabled
    self.excluded = excluded
    self.modes = modes
  }

  public func mode(for calendarID: String) -> CalendarDisplayMode {
    modes[calendarID] ?? .both
  }

  /// Компакт, peek и напоминания
  public func live(_ events: [CalendarEvent]) -> [CalendarEvent] {
    events.filter { passes($0, \.showsLive) }
  }

  /// Duo, календарный вид и меню
  public func expanded(_ events: [CalendarEvent]) -> [CalendarEvent] {
    events.filter { passes($0, \.showsExpanded) }
  }

  private func passes(_ event: CalendarEvent, _ shows: KeyPath<CalendarDisplayMode, Bool>) -> Bool {
    guard isEnabled else { return false }
    guard let id = event.calendarID else { return true }
    return !excluded.contains(id) && mode(for: id)[keyPath: shows]
  }
}

/// Календарь EventKit для строки списка Calendars
public struct CalendarInfo: Equatable, Sendable, Identifiable {
  /// Глиф перед названием: у праздников `)))`, у Birthdays подарок (ui-inspection 1.9)
  public enum Kind: Sendable {
    case regular, subscription, birthdays
  }

  public var id: String
  public var title: String
  public var color: RGB
  public var kind: Kind

  public init(id: String, title: String, color: RGB, kind: Kind = .regular) {
    self.id = id
    self.title = title
    self.color = color
    self.kind = kind
  }
}
