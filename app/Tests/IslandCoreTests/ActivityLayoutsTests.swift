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

    @Test("Самый широкий индикатор до начала — «15m» в момент открытия окна (T−15), с музыкой и без")
    func widestIndicator() {
        for withMusic in [false, true] {
            let opening = ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(-900), showsLine: false, withMusic: withMusic)
            #expect(opening.indicator == ActivityLayouts.calendarWidestIndicator)
        }
    }

    @Test("С музыкой: обложка с бейджем, минуты вверх до начала, в последнюю минуту секунды (Alcove 1.7.9, 29.09)")
    func withMusic() {
        func indicator(_ offset: TimeInterval) -> ActivityLayout.Indicator {
            ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(offset), showsLine: false, withMusic: true).indicator
        }
        #expect(indicator(-484) == .text("9m", color: ActivityLayouts.calendarRed))
        #expect(indicator(-61) == .text("2m", color: ActivityLayouts.calendarRed))
        #expect(indicator(-30) == .text("30s", color: ActivityLayouts.calendarRed))
        #expect(indicator(750) == .ring(progress: 0.5, color: ActivityLayouts.calendarRed, track: ActivityLayouts.calendarTrack))
        #expect(ActivityLayouts.calendar(event: Self.event, now: Self.start, showsLine: false, withMusic: true).showsArtwork)
    }

    @Test("Без музыки до начала — минуты вверх, в последнюю минуту секунды: кольцо только у идущего события")
    func withoutMusic() {
        func indicator(_ offset: TimeInterval) -> ActivityLayout.Indicator {
            ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(offset), showsLine: false).indicator
        }
        #expect(indicator(-900) == .text("15m", color: ActivityLayouts.calendarRed))
        #expect(indicator(-484) == .text("9m", color: ActivityLayouts.calendarRed))
        #expect(indicator(-61) == .text("2m", color: ActivityLayouts.calendarRed))
        // ровно на границе минуты — уже секунды
        #expect(indicator(-60) == .text("60s", color: ActivityLayouts.calendarRed))
        #expect(indicator(-30) == .text("30s", color: ActivityLayouts.calendarRed))
        #expect(!ActivityLayouts.calendar(event: Self.event, now: Self.start.addingTimeInterval(-484), showsLine: false).showsArtwork)
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

    @Test("Низкий заряд наушников — красное кольцо, обычный — зелёное")
    func lowBatteryRing() {
        let low = ActivityLayouts.airpods(AirPodsInfo(name: "AirPods Pro", battery: 0.15, isLowBattery: true))
        let ok = ActivityLayouts.airpods(AirPodsInfo(name: "AirPods Pro", battery: 0.8))
        #expect(low.indicator == .ring(progress: 0.15, color: ActivityLayouts.lowBatteryRed, track: ActivityLayouts.calendarTrack))
        #expect(ok.indicator == .ring(progress: 0.8, color: ActivityLayouts.connectivityGreen, track: ActivityLayouts.connectivityTrack))
    }

    @Test("Глиф по имени: Max, Pro, остальные AirPods — обычный")
    func airpodsSymbol() {
        #expect(AirPodsInfo(name: "AirPods Max", battery: nil).symbol == "airpodsmax")
        #expect(AirPodsInfo(name: "Nikola’s AirPods Pro", battery: nil).symbol == "airpodspro")
        #expect(AirPodsInfo(name: "AirPods 4 (ANC)", battery: nil).symbol == "airpods")
        // переименованные: модель по productID важнее имени, без модели — обычный глиф
        #expect(AirPodsInfo(name: "Studio", battery: nil, model: .max).symbol == "airpodsmax")
        #expect(AirPodsInfo(name: "Studio", battery: nil, model: .pro).symbol == "airpodspro")
        #expect(AirPodsInfo(name: "Pro Kitchen", battery: nil, model: .airpods).symbol == "airpods")
        #expect(AirPodsInfo(name: "Kitchen", battery: nil).symbol == "airpods")
    }
}
