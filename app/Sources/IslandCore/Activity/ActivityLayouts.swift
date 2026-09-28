import Foundation

/// Layout компактов конкретных активностей поверх контракта ActivityLayout
public enum ActivityLayouts {
    /// Красный календарный: иконка, кольцо и секунды одного цвета (ui-inspection 3.5). Точного цвета нет, оценка по кадру
    public static let calendarRed = RGB(red: 1, green: 0.27, blue: 0.23)
    /// Тёмно-красный трек кольца. Оценка по кадру cal-compact.jpg
    public static let calendarTrack = RGB(red: 0.35, green: 0.08, blue: 0.08)
    /// Самый широкий индикатор компакта календаря: окно открывается за минуту до начала, дальше секунды
    /// только убывают, кольцо уже иконки. У Alcove ширина компакта фиксирована, поэтому пол ширины
    /// (IslandGeometry.calendarSize) считается по нему, а не по текущему индикатору
    public static let calendarWidestIndicator = ActivityLayout.Indicator.text("60s", color: calendarRed)
    /// Самый широкий индикатор напоминания: «15m» шире «60s», поэтому у напоминания свой пол ширины
    /// (IslandGeometry.size(for:notch:reminderIndicatorWidth:)). Самое раннее напоминание — за 15 минут
    public static let reminderWidestIndicator = ActivityLayout.Indicator.text("15m", color: calendarRed)

    /// Компакт календаря: до начала — секунды, во время события — кольцо хода.
    /// С showsLine — строка peek на старте: «▌название ⏳ время до конца»
    public static func calendar(event: CalendarEvent, now: Date, showsLine: Bool) -> ActivityLayout {
        let untilStart = event.start.timeIntervalSince(now)
        let indicator: ActivityLayout.Indicator
        if untilStart > 0 {
            indicator = .text("\(Int(untilStart.rounded(.up)))s", color: calendarRed)
        } else {
            let length = max(event.end.timeIntervalSince(event.start), 1)
            indicator = .ring(progress: -untilStart / length, color: calendarRed, track: calendarTrack)
        }
        let line = showsLine
            ? ActivityLayout.Line(bar: event.color, title: event.title, trailingSymbol: "hourglass",
                                  trailing: remaining(event.end.timeIntervalSince(now)))
            : nil
        return ActivityLayout(symbol: "calendar.badge.clock", symbolColor: calendarRed, indicator: indicator, line: line)
    }

    /// Напоминание за N минут: тот же вид, что peek календаря, но вместо кольца — минуты до начала.
    /// У Alcove такого нет (peek Before event starts не снимался): вид — решение плана P1
    public static func reminder(_ reminder: CalendarReminder) -> ActivityLayout {
        ActivityLayout(
            symbol: "calendar.badge.clock", symbolColor: calendarRed,
            indicator: .text("\(reminder.minutes)m", color: calendarRed),
            line: .init(bar: reminder.color, title: reminder.title, trailingSymbol: "clock", trailing: "in \(reminder.minutes) min"))
    }

    /// «59s», «12m», «1h 5m»: как в peek Alcove на старте события
    public static func remaining(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.up))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
