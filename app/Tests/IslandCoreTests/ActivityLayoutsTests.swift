import Foundation
import Testing
@testable import IslandCore

struct ActivityLayoutsTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let event = CalendarEvent(
        id: "e", title: "тест для alcove", start: start, end: start.addingTimeInterval(1500), isAllDay: false,
        color: RGB(red: 0.35, green: 0.85, blue: 0.35))

    @Test("До начала — секунды красным, округление вверх")
    func countdown() {
        let layout = ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(-11.2), showsLine: false)
        #expect(layout.indicator == .text("12s", color: ActivityLayouts.calendarRed))
        #expect(layout.symbol == "calendar.badge.clock")
        #expect(layout.line == nil)
    }

    @Test("Самый широкий индикатор — отсчёт в момент открытия окна, за минуту до начала")
    func widestIndicator() {
        let layout = ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(-60), showsLine: false)
        #expect(layout.indicator == ActivityLayouts.calendarWidestIndicator)
    }

    @Test("Во время события — кольцо хода события")
    func progress() {
        let layout = ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(750), showsLine: false)
        #expect(layout.indicator == .ring(progress: 0.5, color: ActivityLayouts.calendarRed, track: ActivityLayouts.calendarTrack))
    }

    @Test("Peek на старте: полоска цвета календаря, название, песочные часы и время до конца")
    func peekLine() {
        let layout = ActivityLayouts.calendar(event: Self.event, now: Self.start, showsLine: true)
        #expect(layout.line == .init(bar: Self.event.color, title: "тест для alcove", trailingSymbol: "hourglass", trailing: "25m"))
    }

    @Test("Время до конца: секунды, минуты, часы с минутами")
    func remaining() {
        #expect(ActivityLayouts.remaining(59) == "59s")
        #expect(ActivityLayouts.remaining(12 * 60) == "12m")
        #expect(ActivityLayouts.remaining(65 * 60) == "1h 5m")
        #expect(ActivityLayouts.remaining(120 * 60) == "2h")
    }

    @Test("Напоминание: минуты справа и строка «название · in N min»")
    func reminder() {
        let layout = ActivityLayouts.reminder(CalendarReminder(eventID: "e", title: "Созвон", minutes: 15, color: Self.event.color))
        #expect(layout.indicator == .text("15m", color: ActivityLayouts.calendarRed))
        #expect(layout.line == .init(bar: Self.event.color, title: "Созвон", trailingSymbol: "clock", trailing: "in 15 min"))
    }

    @Test("Самый широкий индикатор напоминания — самое раннее напоминание, за 15 минут")
    func reminderWidestIndicator() {
        let earliest = CalendarSchedule.reminderMinutes.max()!
        let layout = ActivityLayouts.reminder(CalendarReminder(eventID: "e", title: "Созвон", minutes: earliest, color: Self.event.color))
        #expect(layout.indicator == ActivityLayouts.reminderWidestIndicator)
    }

    @Test("AirPods: глиф модели белым и зелёное кольцо заряда, без заряда — пустое")
    func airpods() {
        let pro = ActivityLayouts.airpods(AirPodsInfo(name: "AirPods Pro", battery: 0.82))
        #expect(pro.symbol == "airpodspro")
        #expect(pro.symbolColor == ActivityLayouts.glyphWhite)
        #expect(pro.indicator == .ring(progress: 0.82, color: ActivityLayouts.connectivityGreen, track: ActivityLayouts.connectivityTrack))
        #expect(pro.line == nil)
        #expect(ActivityLayouts.airpods(AirPodsInfo(name: "AirPods Max", battery: nil)).indicator
            == .ring(progress: 0, color: ActivityLayouts.connectivityGreen, track: ActivityLayouts.connectivityTrack))
    }

    @Test("Глиф по имени: Max, Pro, остальные AirPods — обычный")
    func airpodsSymbol() {
        #expect(AirPodsInfo(name: "AirPods Max", battery: nil).symbol == "airpodsmax")
        #expect(AirPodsInfo(name: "Nikola’s AirPods Pro", battery: nil).symbol == "airpodspro")
        #expect(AirPodsInfo(name: "AirPods 4 (ANC)", battery: nil).symbol == "airpods")
    }
}
