import Foundation
import Testing

@testable import IslandCore

struct CalendarScheduleTests {
  static let start = Date(timeIntervalSince1970: 1_800_000_000)
  static let event = CalendarEvent(
    id: "call", title: "Созвон", start: start, end: start.addingTimeInterval(1800), isAllDay: false,
    color: RGB(red: 0.2, green: 0.5, blue: 1))
  static let agenda = DayAgenda(today: [event], tomorrow: [])

  static func at(_ offset: TimeInterval) -> Date { start.addingTimeInterval(offset) }

  @Test("Окно календаря: за 15 минут до начала до конца события (Time before event у Alcove 1.7.9)")
  func liveWindow() {
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-901)) == nil)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-900)) == Self.event)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(1799)) == Self.event)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(1800)) == nil)
  }

  @Test("Напоминание в начале окна (T−15) и старт срабатывают при переходе через отметку")
  func crossings() {
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-901), to: Self.at(-899)) == [.reminder(Self.event, minutes: 15)])
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-301), to: Self.at(-300)).isEmpty)
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-1), to: Self.at(0)) == [.started(Self.event)])
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-200), to: Self.at(-100)).isEmpty)
  }

  @Test("После сна отметки старше минуты не показываются")
  func staleMarks() {
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-1000), to: Self.at(-200)).isEmpty)
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-1000), to: Self.at(-850)) == [.reminder(Self.event, minutes: 15)])
  }

  @Test("Следующая граница — ближайшая из окна T−15 (оно же напоминание), старта и конца")
  func nextBoundary() {
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-2000)) == Self.at(-900))
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(0)) == Self.at(1800))
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-30)) == Self.at(0))
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(10)) == Self.at(1800))
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(1800)) == nil)
  }

  @Test("Time before event 5…30 минут двигает окно, напоминание и границу")
  func customLead() {
    let lead: TimeInterval = 5 * 60
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-301), lead: lead) == nil)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-300), lead: lead) == Self.event)
    #expect(
      CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-301), to: Self.at(-300), lead: lead)
        == [.reminder(Self.event, minutes: 5)])
    #expect(CalendarSchedule.crossings(in: Self.agenda, from: Self.at(-901), to: Self.at(-899), lead: lead).isEmpty)
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-2000), lead: lead) == Self.at(-300))
    let long: TimeInterval = 30 * 60
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-1800), lead: long) == Self.event)
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(-2000), lead: long) == Self.at(-1800))
  }

  @Test("Свои отметки события тоже будят часы")
  func extraBoundary() {
    #expect(CalendarSchedule.nextBoundary(in: Self.agenda, after: Self.at(0), extra: { [$0.start.addingTimeInterval(4)] }) == Self.at(4))
  }

  @Test("Пересекающиеся события: окно переходит к начавшемуся позже ровно в момент его старта, после конца — обратно")
  func overlappingLiveEvent() {
    let long = CalendarEvent(
      id: "long", title: "Длинное", start: Self.start, end: Self.at(3600), isAllDay: false, color: Self.event.color)
    let inner = CalendarEvent(
      id: "inner", title: "Внутри", start: Self.at(1800), end: Self.at(2700), isAllDay: false, color: Self.event.color)
    let agenda = DayAgenda.make(events: [inner, long], now: Self.at(-100))
    // до старта inner окно держит long, даже когда T−15 у inner уже прошёл: переход не раньше старта
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(1799)) == long)
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(1800)) == inner)
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(2000)) == inner)
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(2700)) == long)
  }

  @Test("События встык без разрыва: окно переходит к следующему точно в момент его начала, не раньше (Alcove — не проверено, оценка)")
  func adjacentEvents() {
    let a = CalendarEvent(id: "a", title: "A", start: Self.start, end: Self.at(1800), isAllDay: false, color: Self.event.color)
    let b = CalendarEvent(id: "b", title: "B", start: Self.at(1800), end: Self.at(2400), isAllDay: false, color: Self.event.color)
    let agenda = DayAgenda.make(events: [a, b], now: Self.at(-100))
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(900)) == a)
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(1799)) == a)
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(1800)) == b)
  }

  @Test("Событие завтра в начале суток: напоминание, граница и окно работают ещё до полуночи")
  func tomorrowEvent() {
    let agenda = DayAgenda(today: [], tomorrow: [Self.event])
    #expect(CalendarSchedule.crossings(in: agenda, from: Self.at(-901), to: Self.at(-899)) == [.reminder(Self.event, minutes: 15)])
    #expect(CalendarSchedule.nextBoundary(in: agenda, after: Self.at(-2000)) == Self.at(-900))
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(-30)) == Self.event)
  }

  @Test("Disable activity during events: окно до начала как обычно, после старта и peek (hold) — нет")
  func hiddenDuringEvent() {
    let hold: TimeInterval = 4.2
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(-900), hidingAfterStart: hold) == Self.event)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(4), hidingAfterStart: hold) == Self.event)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(4.2), hidingAfterStart: hold) == nil)
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(1000), hidingAfterStart: hold) == nil)
    // без peek на старте компакт уходит в момент старта
    #expect(CalendarSchedule.liveEvent(in: Self.agenda, at: Self.at(0), hidingAfterStart: 0) == nil)
  }

  @Test("Disable activity during events: во время идущего события окно следующего открывается как обычно")
  func nextWindowDuringHiddenEvent() {
    let next = CalendarEvent(
      id: "next", title: "Следующее", start: Self.at(1500), end: Self.at(2400), isAllDay: false, color: Self.event.color)
    let agenda = DayAgenda.make(events: [Self.event, next], now: Self.at(-100))
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(599), hidingAfterStart: 4) == nil)
    #expect(CalendarSchedule.liveEvent(in: agenda, at: Self.at(600), hidingAfterStart: 4) == next)
  }
}
