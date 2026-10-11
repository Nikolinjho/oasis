import IslandCore
import SwiftUI

/// Календарный вид раскрытого 345×175: слева дата и события сегодня, справа ближайший день с событиями
/// или сетка месяца (ui-inspection 1.9, 3.7; осмотр 03.10). AX-фреймов этого вида нет: колонки и отступы по кадрам
/// gest-cycle.jpg и cv-sheet.png, те же, что у Duo, оценка
struct CalendarDayView: View {
  let agenda: DayAgenda
  /// Отклонённые через Dismiss Event: их нет, как в стопке Duo
  var dismissedEvents: Set<String> = []
  var now: Date?
  /// Always show month view и Use event indicators
  var style = CalendarAppearance()
  var calendar: Calendar = .current
  var compact = false
  var onOpen: (() -> Void)?
  let onJoin: (URL) -> Void

  static let shown = 2
  /// Правая колонка у Alcove — до трёх карточек и «N more event» (cv-sheet.png)
  static let nearestShown = 3

  var body: some View {
    if let now {
      content(now)
    } else {
      TimelineView(.everyMinute) { context in content(context.date) }
    }
  }

  private func content(_ now: Date) -> some View {
    let today = Self.today(agenda, now: now, dismissed: dismissedEvents)
    return ZStack(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: -3) {
        Text(DateBadge.weekday(now))
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(IslandPalette.dateAccent)
        Text(DateBadge.day(now))
          .font(.system(size: 34, weight: .light))
          .foregroundStyle(IslandPalette.foreground)
      }
      .contentShape(Rectangle())
      .onTapGesture { onOpen?() }
      .pointerStyle(onOpen == nil ? .default : .link)
      .offset(x: compact ? 0 : 17.5, y: compact ? 0 : 18)

      VStack(alignment: .leading, spacing: 4) {
        if today.isEmpty {
          EmptyDay()
        } else {
          ForEach(visible(today, limit: Self.shown, height: 74)) { event in
            EventCard(event: event, width: eventWidth, onJoin: MeetingLink.find(in: event).map { url in { onJoin(url) } })
          }
          if compact, let more = Self.more(total: today.count, shown: visible(today, limit: Self.shown, height: 74).count) {
            moreButton(more)
          }
        }
      }
      .offset(x: compact ? 0 : 17.5, y: compact ? 52 : 72)

      if style.monthView {
        MonthGridView(
          grid: MonthGrid(containing: now, calendar: calendar), now: now,
          events: style.eventIndicators ? agenda.events : [], calendar: calendar, compact: compact)
      } else {
        nearestColumn(now)
      }
    }
    .frame(width: compact ? 280 : DuoLayout.size.width, height: compact ? 126 : DuoLayout.size.height, alignment: .topLeading)
  }

  /// Ближайший день с событиями в пределах недели (`MON, 5`, завтра — TMRW). Нет — только заголовок TMRW
  private func nearestColumn(_ now: Date) -> some View {
    let nearest = agenda.nearestDay(after: now, calendar: calendar)
    let events = nearest?.events ?? []
    let shown = visible(events, limit: Self.nearestShown, height: 104)
    let hidden = events.dropFirst(shown.count)
    return VStack(alignment: .trailing, spacing: 4) {
      Text(nearest.map { DayAgenda.title(for: $0.day, now: now, calendar: calendar) } ?? "TMRW")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(IslandPalette.secondary)
        .frame(width: eventWidth, height: 18, alignment: .topTrailing)
      ForEach(shown) { event in
        EventCard(event: event, width: eventWidth)
      }
      if let more = Self.more(total: events.count, shown: shown.count), let first = hidden.first {
        HStack(spacing: 5) {
          Capsule().fill(Color(first.color)).frame(width: 3, height: 14)
          Text(more)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(IslandPalette.secondary)
        .padding(.leading, 4)
        .frame(width: eventWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
      }
    }
    .offset(x: compact ? 148 : DuoLayout.eventOrigin.x, y: compact ? 0 : 18)
  }

  private var eventWidth: CGFloat { compact ? 132 : DuoLayout.eventWidth }

  /// Карточки с местом выше: резервируем строку счётчика, чтобы Claude оставался под календарём.
  private func visible(_ events: [CalendarEvent], limit: Int, height: CGFloat) -> [CalendarEvent] {
    guard compact else { return Array(events.prefix(limit)) }
    var result: [CalendarEvent] = []
    var used: CGFloat = 0
    for event in events.prefix(limit) {
      let next = used + (result.isEmpty ? 0 : 4) + EventCard.height(for: event)
      let more: CGFloat = result.count + 1 < events.count ? 18 : 0
      guard next + more <= height else { break }
      result.append(event)
      used = next
    }
    return result
  }

  private func moreButton(_ title: String) -> some View {
    Button(title) { onOpen?() }
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(IslandPalette.secondary)
      .buttonStyle(.plain)
      .frame(height: 14)
  }

  /// Колонка «сегодня» — полный список дня: все незакончившиеся по началу, без отклонённых. Не стопка Duo:
  /// окно календаря у другого события не выкидывает идущие, начавшиеся раньше него
  nonisolated static func today(_ agenda: DayAgenda, now: Date, dismissed: Set<String> = []) -> [CalendarEvent] {
    agenda.today.filter { $0.end > now && !dismissed.contains($0.id) }
  }

  nonisolated static func more(total: Int, shown: Int) -> String? {
    let rest = total - shown
    guard rest > 0 else { return nil }
    return rest == 1 ? "1 more event" : "\(rest) more events"
  }
}
