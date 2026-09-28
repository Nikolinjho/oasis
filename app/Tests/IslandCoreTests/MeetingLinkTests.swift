import Foundation
import Testing
@testable import IslandCore

struct MeetingLinkTests {
    static func event(url: String? = nil, location: String? = nil, notes: String? = nil) -> CalendarEvent {
        CalendarEvent(
            id: "e", title: "Созвон", start: Date(), end: Date().addingTimeInterval(1800), isAllDay: false,
            color: RGB(red: 0, green: 0, blue: 1), url: url.flatMap(URL.init(string:)), location: location, notes: notes)
    }

    @Test("Сервисы созвонов находятся в заметках", arguments: [
        "https://meet.google.com/abc-defg-hij",
        "https://us02web.zoom.us/j/81234567890?pwd=xyz",
        "https://telemost.yandex.ru/j/12345678901234",
        "https://telemost.360.yandex.ru/j/12345678901234",
        "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc",
        "https://teams.live.com/meet/9876543210",
    ])
    func services(link: String) {
        let found = MeetingLink.find(in: Self.event(notes: "Повестка в доке.\nПодключиться: \(link)\nСпасибо"))
        #expect(found?.absoluteString == link)
    }

    @Test("Поле URL важнее места, место важнее заметок")
    func priority() {
        let event = Self.event(
            url: "https://meet.google.com/aaa-bbbb-ccc",
            location: "https://zoom.us/j/1",
            notes: "https://telemost.yandex.ru/j/2")
        #expect(MeetingLink.find(in: event)?.host() == "meet.google.com")
        #expect(MeetingLink.find(in: Self.event(location: "https://zoom.us/j/1", notes: "https://telemost.yandex.ru/j/2"))?.host() == "zoom.us")
    }

    @Test("Ссылки не на созвоны не берутся")
    func ignoresOtherLinks() {
        #expect(MeetingLink.find(in: Self.event(url: "https://app.asana.com/0/1/2", notes: "https://docs.google.com/x")) == nil)
        #expect(MeetingLink.find(in: Self.event(location: "Переговорная 3")) == nil)
    }
}
