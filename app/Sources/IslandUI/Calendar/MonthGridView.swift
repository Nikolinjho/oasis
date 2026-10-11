import IslandCore
import SwiftUI

/// Сетка месяца правой колонки календарного вида (Always show month view, осмотр Alcove 03.10, cv-sheet.png).
/// Координаты по кадру 2×: колонки по 21 pt до правого края колонки событий Duo, строки по 20 pt
struct MonthGridView: View {
  let grid: MonthGrid
  let now: Date
  /// События месяца для индикаторов. Пусто, если Use event indicators выключен
  var events: [CalendarEvent] = []
  var calendar: Calendar = .current
  var compact = false

  private var cell: CGSize { compact ? CGSize(width: 19, height: 16) : Self.cell }
  private var left: CGFloat { compact ? 147 : Self.left }
  private var titleY: CGFloat { compact ? 7 : Self.titleCenterY }
  private var weekdayY: CGFloat { compact ? 24 : Self.weekdayCenterY }
  private var firstRowY: CGFloat { compact ? 38 : Self.firstRowCenterY }

  static let cell = CGSize(width: 21, height: 20)
  /// Левый край сетки: 7 колонок кончаются у правого края колонки событий (188.5 + 138)
  static let left = DuoLayout.eventOrigin.x + DuoLayout.eventWidth - 7 * cell.width
  static let titleCenterY: CGFloat = 24.5
  static let weekdayCenterY: CGFloat = 45.5
  static let firstRowCenterY: CGFloat = 65
  static let todayDiameter: CGFloat = 18
  static let indicator = CGSize(width: 4, height: 1.5)

  var body: some View {
    ZStack(alignment: .topLeading) {
      Text(grid.title)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(IslandPalette.dateAccent)
        .frame(width: 7 * cell.width, alignment: .trailing)
        .position(x: left + 3.5 * cell.width, y: titleY)
      ForEach(Array(MonthGrid.weekdaySymbols.enumerated()), id: \.offset) { column, symbol in
        Text(symbol)
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(MonthGrid.isWeekend(column: column) ? IslandPalette.secondary : IslandPalette.foreground)
          .position(x: centerX(column), y: weekdayY)
      }
      ForEach(Array(grid.weeks.enumerated()), id: \.offset) { row, week in
        ForEach(Array(week.enumerated()), id: \.offset) { column, day in
          if let day {
            dayCell(day, column: column)
              .position(x: centerX(column), y: firstRowY + CGFloat(row) * cell.height)
          }
        }
      }
    }
    .frame(width: compact ? 280 : DuoLayout.size.width, height: compact ? 126 : DuoLayout.size.height, alignment: .topLeading)
  }

  private func dayCell(_ day: Date, column: Int) -> some View {
    let isToday = calendar.isDate(day, inSameDayAs: now)
    // у сегодняшнего числа черточек нет: на кадре Alcove (cv-sheet2.png) под красным кругом их не видно
    let colors = events.isEmpty || isToday ? [] : MonthGrid.indicators(on: day, events: events, calendar: calendar)
    return Text("\(calendar.component(.day, from: day))")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(
        isToday ? IslandPalette.foreground : MonthGrid.isWeekend(column: column) ? IslandPalette.secondary : IslandPalette.foreground
      )
      .frame(width: compact ? 16 : Self.todayDiameter, height: compact ? 16 : Self.todayDiameter)
      .background(Circle().fill(isToday ? IslandPalette.dateAccent : .clear))
      // черточки под числом: по одной на календарь с событиями этого дня, в его цвете
      .overlay(alignment: .bottom) {
        HStack(spacing: 1) {
          ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
            Capsule().fill(Color(color)).frame(width: Self.indicator.width, height: Self.indicator.height)
          }
        }
        .offset(y: 1.5)
      }
  }

  static func centerX(_ column: Int) -> CGFloat {
    left + (CGFloat(column) + 0.5) * cell.width
  }

  private func centerX(_ column: Int) -> CGFloat {
    left + (CGFloat(column) + 0.5) * cell.width
  }
}
