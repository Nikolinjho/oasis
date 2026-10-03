import Foundation
import IslandCore
import SwiftUI
import Testing

@testable import IslandUI

struct CalendarDayViewTests {
  static let base = Date(timeIntervalSince1970: 1_790_000_000)

  static func event(_ id: String, _ hours: Double, color: RGB = RGB(red: 0.35, green: 0.85, blue: 0.35)) -> CalendarEvent {
    CalendarEvent(
      id: id, title: id, start: base.addingTimeInterval(hours * 3600),
      end: base.addingTimeInterval(hours * 3600 + 1800), isAllDay: false, color: color)
  }

  @Test("Строка «ещё N событий»: число и форма слова")
  func more() {
    #expect(CalendarDayView.more(total: 4, shown: 2) == "2 more events")
    #expect(CalendarDayView.more(total: 3, shown: 2) == "1 more event")
    #expect(CalendarDayView.more(total: 2, shown: 2) == nil)
  }

  @Test("Сегодня — полный список дня: идущая «Планёрка» не пропадает, когда открылось окно следующей встречи")
  func todayKeepsRunningEvents() {
    let standup = CalendarEvent(
      id: "Планёрка", title: "Планёрка", start: Self.base, end: Self.base.addingTimeInterval(3 * 3600), isAllDay: false,
      color: RGB(red: 1, green: 0, blue: 0))
    let meeting = Self.event("Встреча", 2)
    let later = Self.event("Ретро", 4)
    let done = Self.event("Завтрак", -1)
    let agenda = DayAgenda(today: [done, standup, meeting, later], tomorrow: [])
    // 11:45 при «Планёрке» с 10:00: окно «Встречи» в 12:00 уже открыто, «Планёрка» ещё идёт
    let now = Self.base.addingTimeInterval(1.75 * 3600)
    #expect(CalendarDayView.today(agenda, now: now).map(\.id) == ["Планёрка", "Встреча", "Ретро"])
    #expect(CalendarDayView.today(agenda, now: now, dismissed: ["Встреча"]).map(\.id) == ["Планёрка", "Ретро"])
  }

  static var moscow: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return calendar
  }

  /// Как на осмотре Alcove 03.10 (cv-sheet.png): суббота, 3 октября 2026, 13:00 MSK
  static func october(_ day: Int, _ hour: Double) -> Date {
    moscow.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 0))!.addingTimeInterval(hour * 3600)
  }

  static func october(_ id: String, _ day: Int, _ hour: Double, hours: Double = 0.5, allDay: Bool = false, color: RGB, calendar: String)
    -> CalendarEvent
  {
    CalendarEvent(
      id: id, title: id, start: october(day, hour), end: october(day, hour + hours), isAllDay: allDay, color: color,
      calendarID: calendar, calendarKind: calendar == "holidays" ? .subscription : .regular)
  }

  @Test("Звёздочка — только у событий на весь день из подписок-праздников, остальные с полоской")
  func star() {
    let holiday = Self.october("Праздник", 5, 0, hours: 24, allDay: true, color: Self.blue, calendar: "holidays")
    let vacation = Self.october("Отпуск", 5, 0, hours: 24, allDay: true, color: Self.blue, calendar: "home")
    let timed = Self.october("Подписка", 5, 10, color: Self.blue, calendar: "holidays")
    #expect(EventCard.showsStar(holiday))
    #expect(!EventCard.showsStar(vacation))
    #expect(!EventCard.showsStar(timed))
  }

  static let orange = RGB(red: 0.93, green: 0.55, blue: 0.35)
  static let teal = RGB(red: 0.55, green: 0.8, blue: 0.9)
  static let blue = RGB(red: 0.3, green: 0.6, blue: 1)
  static let green = RGB(red: 0.4, green: 0.85, blue: 0.4)

  /// Неделя как на кадрах Alcove: сегодня два теста, завтра пусто, в понедельник праздник, зал, daily и ещё одно
  static var octoberAgenda: DayAgenda {
    var events = [
      october("Oasis test — удалить", 3, 13.35, color: orange, calendar: "icloud"),
      october("Oasis test 2 — удалить", 3, 14.07, color: orange, calendar: "icloud"),
      october("День учителя", 5, 0, hours: 24, allDay: true, color: blue, calendar: "holidays"),
      october("Зал", 5, 8, hours: 1.5, color: teal, calendar: "work"),
      october("Team # daily", 5, 11.5, hours: 1, color: teal, calendar: "work"),
      october("Ретро", 5, 15, color: teal, calendar: "work"),
    ]
    for day in [1, 2, 6, 7, 8, 9, 12, 13, 14, 15, 16, 19, 20, 21, 22, 23, 26, 27, 28, 29, 30] {
      events.append(october("daily \(day)", day, 11.5, color: teal, calendar: "work"))
    }
    for day in [14, 17, 19, 30] { events.append(october("home \(day)", day, 19, color: green, calendar: "home")) }
    return DayAgenda.make(events: events, now: october(3, 13), calendar: moscow)
  }

  @MainActor
  @Test("Снимок календарного вида: справа ближайший день с событиями — понедельник, три карточки и «1 more event»")
  func snapshot() throws {
    let spec = IslandShapeSpec(size: IslandGeometry.expanded, bottomRadius: 35)
    let view = ZStack(alignment: .topLeading) {
      IslandShape(spec: spec, shoulder: 0).fill(IslandPalette.background)
      CalendarDayView(agenda: Self.octoberAgenda, now: Self.october(3, 13), calendar: Self.moscow, onJoin: { _ in })
    }
    try Snapshot.write(view, size: IslandGeometry.expanded, name: "calendar-day")
  }

  @MainActor
  @Test("Снимок сетки месяца с индикаторами событий")
  func monthSnapshot() throws {
    var style = CalendarAppearance()
    style.monthView = true
    style.eventIndicators = true
    let spec = IslandShapeSpec(size: IslandGeometry.expanded, bottomRadius: 35)
    let view = ZStack(alignment: .topLeading) {
      IslandShape(spec: spec, shoulder: 0).fill(IslandPalette.background)
      CalendarDayView(
        agenda: Self.octoberAgenda, now: Self.october(3, 13), style: style, calendar: Self.moscow, onJoin: { _ in })
    }
    try Snapshot.write(view, size: IslandGeometry.expanded, name: "calendar-month")
  }
}
