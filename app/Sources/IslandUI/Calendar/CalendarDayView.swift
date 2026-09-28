import IslandCore
import SwiftUI

/// Календарный вид раскрытого 345×175: слева дата и события сегодня, справа TMRW и завтра (ui-inspection 3.7).
/// AX-фреймов этого вида нет: колонки и отступы по кадру gest-cycle.jpg, те же, что у Duo, оценка
struct CalendarDayView: View {
    let agenda: DayAgenda
    var now: Date? = nil
    let onJoin: (URL) -> Void

    static let shown = 2

    var body: some View {
        if let now {
            content(now)
        } else {
            TimelineView(.everyMinute) { context in content(context.date) }
        }
    }

    private func content(_ now: Date) -> some View {
        let today = agenda.today.filter { $0.end > now }
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: -3) {
                Text(DateBadge.weekday(now))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(IslandPalette.dateAccent)
                Text(DateBadge.day(now))
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(IslandPalette.foreground)
            }
            .offset(x: 17.5, y: 18)

            VStack(alignment: .leading, spacing: 4) {
                if today.isEmpty {
                    EmptyDay()
                } else {
                    ForEach(today.prefix(Self.shown)) { event in
                        EventCard(event: event, onJoin: MeetingLink.find(in: event).map { url in { onJoin(url) } })
                    }
                }
            }
            .offset(x: 17.5, y: 72)

            // пустой завтрашний день: только заголовок TMRW. Как это рисует Alcove, эталона нет
            VStack(alignment: .trailing, spacing: 4) {
                Text("TMRW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(IslandPalette.secondary)
                    .frame(width: DuoLayout.eventSize.width, alignment: .trailing)
                ForEach(agenda.tomorrow.prefix(Self.shown)) { event in
                    EventCard(event: event)
                }
                if let more = Self.more(total: agenda.tomorrow.count, shown: Self.shown) {
                    Text(more)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(IslandPalette.secondary)
                        .frame(width: DuoLayout.eventSize.width, alignment: .leading)
                }
            }
            .offset(x: DuoLayout.eventOrigin.x, y: 18)
        }
        .frame(width: DuoLayout.size.width, height: DuoLayout.size.height, alignment: .topLeading)
    }

    nonisolated static func more(total: Int, shown: Int) -> String? {
        let rest = total - shown
        guard rest > 0 else { return nil }
        return rest == 1 ? "1 more event" : "\(rest) more events"
    }
}
