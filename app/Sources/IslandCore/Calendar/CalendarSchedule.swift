import Foundation

/// Что произошло в календаре между двумя тиками часов
public enum CalendarTick: Equatable, Sendable {
    case reminder(CalendarEvent, minutes: Int)
    case started(CalendarEvent)
}

/// Время календаря (решение 27.09): напоминания за 15 и 5 минут, компакт с минуты до начала, peek на старте
public enum CalendarSchedule {
    public static let reminderMinutes = [15, 5]
    /// Компакт календаря появляется за минуту до начала
    public static let liveLead: TimeInterval = 60
    /// Отметку старше этого (Mac спал, таймер опоздал) уже не показываем
    public static let staleAfter: TimeInterval = 60

    /// Событие окна календаря: самое раннее из тех, что начнутся в ближайшую минуту или уже идут
    public static func liveEvent(in agenda: DayAgenda, at now: Date) -> CalendarEvent? {
        agenda.today.first { $0.start.addingTimeInterval(-liveLead) <= now && now < $0.end }
    }

    public static func crossings(in agenda: DayAgenda, from previous: Date, to now: Date) -> [CalendarTick] {
        guard now > previous else { return [] }
        var ticks: [CalendarTick] = []
        for event in agenda.today {
            for minutes in reminderMinutes where crossed(reminderMark(event, minutes), previous, now) {
                ticks.append(.reminder(event, minutes: minutes))
            }
            if crossed(event.start, previous, now) { ticks.append(.started(event)) }
        }
        return ticks
    }

    /// Ближайшая граница после now: по ней часы просыпаются
    public static func nextBoundary(in agenda: DayAgenda, after now: Date) -> Date? {
        agenda.today
            .flatMap { event in
                reminderMinutes.map { reminderMark(event, $0) }
                    + [event.start.addingTimeInterval(-liveLead), event.start, event.end]
            }
            .filter { $0 > now }
            .min()
    }

    static func reminderMark(_ event: CalendarEvent, _ minutes: Int) -> Date {
        event.start.addingTimeInterval(-Double(minutes) * 60)
    }

    private static func crossed(_ mark: Date, _ previous: Date, _ now: Date) -> Bool {
        previous < mark && mark <= now && now.timeIntervalSince(mark) <= staleAfter
    }
}
