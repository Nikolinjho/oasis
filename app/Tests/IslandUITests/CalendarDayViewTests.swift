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

  @MainActor
  @Test("Снимок календарного вида: сегодня и завтра")
  func snapshot() throws {
    let gray = RGB(red: 0.55, green: 0.65, blue: 0.75)
    let agenda = DayAgenda(
      today: [Self.event("Энхиридион", 1)],
      tomorrow: [
        Self.event("Зал", 10, color: gray), Self.event("Фронтенд Q/A", 12, color: gray),
        Self.event("Ретро", 15, color: gray), Self.event("1:1", 17, color: gray),
      ])
    let spec = IslandShapeSpec(size: IslandGeometry.expanded, bottomRadius: 35)
    let view = ZStack(alignment: .topLeading) {
      IslandShape(spec: spec, shoulder: 0).fill(IslandPalette.background)
      CalendarDayView(agenda: agenda, now: Self.base, onJoin: { _ in })
    }
    try Snapshot.write(view, size: IslandGeometry.expanded, name: "calendar-day")
  }
}
