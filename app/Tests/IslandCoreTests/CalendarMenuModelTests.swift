import Foundation
import Testing
@testable import IslandCore

struct CalendarMenuModelTests {
    static let now = Date(timeIntervalSince1970: 1_790_530_200)

    static func event(_ id: String, startsIn minutes: Double, length: Double = 30, notes: String? = nil) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(
            id: id, title: "Созвон", start: start, end: start.addingTimeInterval(length * 60), isAllDay: false,
            color: RGB(red: 0.2, green: 0.5, blue: 1), notes: notes)
    }

    static func model(_ events: [CalendarEvent], tomorrow: [CalendarEvent] = [], dismissed: Set<String> = []) -> CalendarMenuModel? {
        CalendarMenuModel.make(agenda: DayAgenda(today: events, tomorrow: tomorrow), now: now, dismissed: dismissed)
    }

    @Test("Пункты с T−15 до конца события")
    func window() {
        #expect(Self.model([Self.event("a", startsIn: 16)]) == nil)
        #expect(Self.model([Self.event("a", startsIn: 15)])?.event.id == "a")
        #expect(Self.model([Self.event("a", startsIn: 8)])?.event.id == "a")
        #expect(Self.model([Self.event("a", startsIn: -10)])?.event.id == "a")
        #expect(Self.model([Self.event("a", startsIn: -30)]) == nil)
        #expect(Self.model([Self.event("a", startsIn: -40)]) == nil)
    }

    @Test("Самое раннее событие, отклонённое пропускается")
    func earliestAndDismissed() {
        let events = [Self.event("a", startsIn: 2), Self.event("b", startsIn: 10)]
        #expect(Self.model(events)?.event.id == "a")
        #expect(Self.model(events, dismissed: ["a"])?.event.id == "b")
        #expect(Self.model(events, dismissed: ["a", "b"]) == nil)
    }

    @Test("Событие завтра в начале суток: пункты уже накануне, как напоминания CalendarSchedule")
    func tomorrowEvent() {
        let early = Self.event("night", startsIn: 10)
        #expect(Self.model([], tomorrow: [early])?.event.id == "night")
        #expect(Self.model([], tomorrow: [early], dismissed: ["night"]) == nil)
    }

    @Test("Join по сервису ссылки, без ссылки пункта нет")
    func joinTitle() {
        #expect(Self.model([Self.event("a", startsIn: 5, notes: "https://meet.google.com/abc-defg-hij")])?.joinTitle == "Join Google Meet")
        #expect(Self.model([Self.event("a", startsIn: 5, notes: "https://us02web.zoom.us/j/123")])?.joinTitle == "Join Zoom")
        #expect(Self.model([Self.event("a", startsIn: 5, notes: "https://zoomgov.com/j/1")])?.joinTitle == "Join Zoom")
        #expect(Self.model([Self.event("a", startsIn: 5, notes: "https://telemost.yandex.ru/j/1")])?.joinTitle == "Join Telemost")
        #expect(Self.model([Self.event("a", startsIn: 5, notes: "https://teams.microsoft.com/l/meetup-join/1")])?.joinTitle == "Join Microsoft Teams")
        #expect(Self.model([Self.event("a", startsIn: 5, notes: "https://teams.cloud.microsoft/l/meetup-join/1")])?.joinTitle == "Join Microsoft Teams")
        let plain = Self.model([Self.event("a", startsIn: 5)])
        #expect(plain?.meeting == nil)
        #expect(plain?.joinTitle == nil)
    }

    @Test("Каждый хост MeetingLink узнаётся как сервис: найденная ссылка всегда даёт Join с именем")
    func everyHostHasService() {
        for host in MeetingLink.hosts {
            #expect(MeetingService(url: URL(string: "https://\(host)/j/1")!) != nil, "\(host)")
            #expect(MeetingService(url: URL(string: "https://sub.\(host)/j/1")!) != nil, "sub.\(host)")
        }
        #expect(MeetingService(url: URL(string: "https://notzoom.us/j/1")!) == nil)
    }

    @Test("Ссылка на событие в Calendar.app: eventIdentifier без отметки начала")
    func calendarURL() {
        let model = Self.model([Self.event("ABC-1:DEF-2@1790530200.0", startsIn: 5)])
        #expect(model?.calendarURL?.absoluteString == "ical://ekevent/ABC-1:DEF-2?method=show&options=more")
        // Exchange и CalDAV: в id бывают «/», «+» и пробел. «/» кодируется, иначе id распадётся на сегменты пути
        let exchange = Self.model([Self.event("AAMk/B+C D:E@1790530200.0", startsIn: 5)])
        #expect(exchange?.calendarURL?.absoluteString == "ical://ekevent/AAMk%2FB+C%20D:E?method=show&options=more")
    }
}
