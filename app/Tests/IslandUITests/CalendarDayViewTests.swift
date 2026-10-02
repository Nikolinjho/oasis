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
