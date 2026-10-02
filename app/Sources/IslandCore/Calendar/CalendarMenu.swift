import Foundation

/// Сервис созвона по хосту ссылки: имя для «Join %@» (ui-strings menu.calendar.join).
/// Хосты сервисов — единый список: по нему же MeetingLink ищет ссылку в событии
public enum MeetingService: Equatable, Sendable, CaseIterable {
  case googleMeet, zoom, telemost, teams

  public var hosts: [String] {
    switch self {
    case .googleMeet: ["meet.google.com"]
    case .zoom: ["zoom.us", "zoom.com", "zoomgov.com"]
    case .telemost: ["telemost.yandex.ru", "telemost.360.yandex.ru"]
    case .teams: ["teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft"]
    }
  }

  public init?(url: URL) {
    guard let host = url.host()?.lowercased(),
      let service = Self.allCases.first(where: { $0.hosts.contains { Self.host(host, matches: $0) } })
    else { return nil }
    self = service
  }

  /// Сам домен или его поддомен: us02web.zoom.us — Zoom, notzoom.us — нет
  static func host(_ host: String, matches domain: String) -> Bool {
    host == domain || host.hasSuffix("." + domain)
  }

  public var name: String {
    switch self {
    case .googleMeet: "Google Meet"
    case .zoom: "Zoom"
    case .telemost: "Telemost"
    case .teams: "Microsoft Teams"
    }
  }
}

/// Пункты события вверху меню: Join, Open in Calendar, Dismiss Event (скрин меню Alcove 28.09, ui-strings menu.calendar.*)
public struct CalendarMenuModel: Equatable, Sendable {
  /// Пункты видны с T−15: «Time before event» у Alcove по умолчанию 15 m (ui-inspection 1.9). На скрине — за 8 минут до начала
  public static let lead: TimeInterval = 15 * 60
  public static let openTitle = "Open in Calendar"
  public static let dismissTitle = "Dismiss Event"

  public var event: CalendarEvent
  public var meeting: URL?

  public init(event: CalendarEvent, meeting: URL?) {
    self.event = event
    self.meeting = meeting
  }

  /// Самое раннее не отклонённое событие от T−15 до конца. Нет такого — nil.
  /// Завтрашние после сегодняшних, как в CalendarSchedule: у события в 00:05 напоминание и окно наступают накануне
  public static func make(agenda: DayAgenda, now: Date, dismissed: Set<String>) -> CalendarMenuModel? {
    guard
      let event = (agenda.today + agenda.tomorrow).first(where: {
        !dismissed.contains($0.id) && $0.start.addingTimeInterval(-lead) <= now && now < $0.end
      })
    else { return nil }
    return CalendarMenuModel(event: event, meeting: MeetingLink.find(in: event))
  }

  public var service: MeetingService? { meeting.flatMap(MeetingService.init(url:)) }

  /// «Join Google Meet». Ссылки нет — nil, пункта нет
  public var joinTitle: String? {
    meeting.map { _ in "Join \(service?.name ?? "Call")" }
  }

  /// Событие в Calendar.app. id события — «eventIdentifier@начало» (P0 Task 6): берём часть до последней «@»
  public var calendarURL: URL? {
    let identifier = event.id.lastIndex(of: "@").map { String(event.id[..<$0]) } ?? event.id
    // двоеточие между UUID календаря и события оставляем как есть: так ссылку ical://ekevent/ собирают
    // и другие клиенты, а urlPathAllowed кодирует его в %3A (тест calendarURL). «/» кодируем: id Exchange
    // и CalDAV бывают с «/», и без кодирования id распался бы на сегменты пути
    var allowed = CharacterSet.urlPathAllowed.union(CharacterSet(charactersIn: ":"))
    allowed.remove(charactersIn: "/")
    guard let encoded = identifier.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
    return URL(string: "ical://ekevent/\(encoded)?method=show&options=more")
  }
}
