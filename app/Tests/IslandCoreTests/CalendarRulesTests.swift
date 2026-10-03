import Testing

@testable import IslandCore

/// Страница Calendar → Extension и звук: что машина делает на старте события и с напоминанием
struct CalendarRulesTests {
  static let reminder = IslandAlert.calendarReminder(
    CalendarReminder(eventID: "call", title: "Созвон", minutes: 15, color: RGB(red: 0.2, green: 0.5, blue: 1)))

  static func model(_ surface: Surface, rules: CalendarRules) -> IslandModel {
    var config = IslandMachine.Config.alcove
    config.calendar = rules
    var model = IslandModel(config: config)
    model.surface = surface
    model.calendarLive = true
    return model
  }

  @Test("Peek duration 4 с — те же 4.2 с, что замер Alcove: к настройке прибавляется вход и уход")
  func peekDuration() {
    #expect(CalendarRules().peekDuration == IslandTiming.calendarPeek)
    #expect(CalendarRules.peekDuration(seconds: 4) == IslandTiming.calendarPeek)
    #expect(CalendarRules.peekDuration(seconds: 1) == .milliseconds(1200))
  }

  @Test("Peek на старте держится Peek duration из настроек")
  func peekUsesDuration() {
    var rules = CalendarRules()
    rules.peekDuration = .milliseconds(6200)
    var m = Self.model(.calendar, rules: rules)
    let fx = IslandMachine.reduce(&m, .calendarStarted)
    #expect(fx == [.animate(.calendarPeekOpen), .schedule(.calendarPeekEnd, after: .milliseconds(6200)), .play(.event)])
  }

  @Test("Quick Peek или When event is starting выкл — на старте только звук, компакт остаётся")
  func noPeekOnStart() {
    var rules = CalendarRules()
    rules.peeksOnStart = false
    var m = Self.model(.calendar, rules: rules)
    #expect(IslandMachine.reduce(&m, .calendarStarted) == [.play(.event)])
    #expect(m.surface == .calendar)
  }

  @Test("Play sound on calendar event выкл — peek без звука, из раскрытого ничего")
  func silent() {
    var rules = CalendarRules()
    rules.sound = false
    var m = Self.model(.calendar, rules: rules)
    #expect(
      IslandMachine.reduce(&m, .calendarStarted) == [
        .animate(.calendarPeekOpen), .schedule(.calendarPeekEnd, after: IslandTiming.calendarPeek),
      ])
    var open = Self.model(.expanded, rules: rules)
    #expect(IslandMachine.reduce(&open, .calendarStarted).isEmpty)
  }

  @Test("Напоминание держится Peek duration и звучит только при Play sound on calendar event")
  func reminderRules() {
    var rules = AlertRules()
    #expect(rules.duration(for: Self.reminder) == IslandTiming.calendarPeek)
    #expect(rules.sound(for: Self.reminder) == .event)
    rules.calendar.peekDuration = .milliseconds(2200)
    rules.calendar.sound = false
    #expect(rules.duration(for: Self.reminder) == .milliseconds(2200))
    #expect(rules.sound(for: Self.reminder) == nil)
  }
}
