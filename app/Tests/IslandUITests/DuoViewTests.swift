import Foundation
import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct DuoViewTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    static func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: hour, minute: minute))!
    }

    static let event = CalendarEvent(
        id: "e", title: "тест для alcove", start: at(23, 5), end: at(23, 30), isAllDay: false,
        color: RGB(red: 0.35, green: 0.85, blue: 0.35))

    @Test("Дата как в Alcove: день недели капсом по-английски и число")
    func dateBadge() {
        #expect(DateBadge.weekday(Self.at(23, 10), calendar: Self.calendar) == "SAT")
        #expect(DateBadge.day(Self.at(23, 10), calendar: Self.calendar) == "26")
    }

    @Test("Время события в 12-часовом формате с тире, как в Alcove")
    func eventTime() {
        #expect(EventCard.timeRange(Self.event, calendar: Self.calendar) == "11:05 PM – 11:30 PM")
    }

    @Test("Кнопки Duo: перемотки и play/pause по состоянию")
    func controls() {
        let playing = NowPlayingInfo(title: "Fire", isPlaying: true)
        #expect(DuoControl.row(playing).map(\.symbol) == ["backward.fill", "pause.fill", "forward.fill"])
        #expect(DuoControl.row(nil).map(\.symbol) == ["backward.fill", "play.fill", "forward.fill"])
        #expect(DuoControl.row(nil).map(\.action) == [.media(.previousTrack), .media(.togglePlayPause), .media(.nextTrack)])
    }

    @Test("Карточка события: с местом 40 pt, без места 28 (AX Alcove 1.7.9, 29.09)")
    func cardHeight() {
        var event = CalendarEvent(
            id: "e", title: "Шарп SEO", start: .now, end: .now.addingTimeInterval(3600), isAllDay: false,
            color: RGB(red: 0.4, green: 0.7, blue: 1))
        #expect(EventCard.height(for: event) == 28)
        event.location = "Двор-1-Камчатка (30)"
        #expect(EventCard.height(for: event) == 40)
        event.location = "  "
        #expect(EventCard.height(for: event) == 28)
    }

    @Test("Стопка в колонке Duo: 40 + 28 помещаются, из трёх по 28 — две")
    func fitting() {
        func event(_ id: String, location: String? = nil) -> CalendarEvent {
            CalendarEvent(
                id: id, title: id, start: .now, end: .now.addingTimeInterval(600), isAllDay: false,
                color: RGB(red: 1, green: 0, blue: 0), location: location)
        }
        #expect(DuoLayout.fitting([event("a", location: "Room"), event("b")]).map(\.id) == ["a", "b"])
        #expect(DuoLayout.fitting([event("a"), event("b"), event("c")]).map(\.id) == ["a", "b"])
        #expect(DuoLayout.fitting([]).isEmpty)
    }

    @MainActor
    @Test("Снимки Duo с событием и с пустым днём")
    func snapshots() throws {
        let info = NowPlayingInfo(title: "WE FACED THE BEST TEAM?", artist: "Khomchik", isPlaying: false)
        let spec = IslandShapeSpec(size: IslandGeometry.expanded, bottomRadius: 35)
        for (name, agenda) in [
            ("duo-event", DayAgenda(today: [Self.event], tomorrow: [])),
            ("duo-empty", DayAgenda.empty),
        ] {
            let view = ZStack(alignment: .topLeading) {
                IslandShape(spec: spec, shoulder: 0).fill(IslandPalette.background)
                DuoView(info: info, agenda: agenda, now: Self.at(23, 10), onAction: { _ in })
            }
            try Snapshot.write(view, size: IslandGeometry.expanded, name: name)
        }
    }
}
