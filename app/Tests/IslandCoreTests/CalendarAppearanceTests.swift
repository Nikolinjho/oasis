import Foundation
import Testing

@testable import IslandCore

/// Calendar → Use calendar color и Use colored calendar indicator (осмотр Alcove 03.10, ui-inspection 1.9)
struct CalendarAppearanceTests {
  static let start = ActivityLayoutsTests.start
  static let event = ActivityLayoutsTests.event
  static let orange = RGB(red: 1, green: 0.6, blue: 0.2)

  static func colored(_ on: Bool) -> CalendarAppearance {
    var style = CalendarAppearance()
    style.usesCalendarColor = on
    return style
  }

  @Test("Use calendar color: иконка, минуты, секунды и кольцо компакта в цвете календаря, трек — его тёмный вариант")
  func calendarColor() {
    let event = CalendarEvent(
      id: "e", title: "e", start: Self.start, end: Self.start.addingTimeInterval(1000), isAllDay: false, color: Self.orange)
    let track = RGB(red: 0.35, green: 0.21, blue: 0.07)
    func layout(_ offset: TimeInterval) -> ActivityLayout {
      ActivityLayouts.calendar(event: event, now: Self.start.addingTimeInterval(offset), showsLine: false, style: Self.colored(true))
    }
    #expect(layout(-300).symbolColor == Self.orange)
    #expect(layout(-300).indicator == .text("5m", color: Self.orange))
    #expect(layout(-30).indicator == .text("30s", color: Self.orange))
    guard case .ring(let progress, let color, let ringTrack) = layout(500).indicator else {
      Issue.record("ожидалось кольцо")
      return
    }
    #expect(progress == 0.5)
    #expect(color == Self.orange)
    #expect(abs(ringTrack.red - track.red) < 0.001 && abs(ringTrack.green - track.green) < 0.001)
    #expect(abs(ringTrack.blue - track.blue) < 0.001)
  }

  @Test("Use calendar color выкл (по умолчанию) — красный, как раньше")
  func defaultRed() {
    let layout = ActivityLayouts.calendar(event: Self.event, now: Self.start, showsLine: false, style: Self.colored(false))
    #expect(layout.symbolColor == ActivityLayouts.calendarRed)
    #expect(layout == ActivityLayouts.calendar(event: Self.event, now: Self.start, showsLine: false))
  }
}
