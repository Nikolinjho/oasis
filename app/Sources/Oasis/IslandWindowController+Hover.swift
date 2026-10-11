import IslandCore

extension IslandWindowController {
  /// Флаг закрытия свайпом держится, пока курсор над островом и остров не раскрыт снова (кликом,
  /// отладкой): иначе он пережил бы новое раскрытие и съел законное переоткрытие после следующего уведомления
  static func keepsClosedBySwipe(_ flag: Bool, surface: Surface, pointerInside: Bool) -> Bool {
    flag && pointerInside && surface != .expanded
  }

  /// true, если сейчас стоит досылать hoverEntered: курсор над островом и surface — состояние покоя
  /// (idle/compact/peek/calendar/calendarPeek). Раскрытые им состояния (hover, hoverNudge, expanded)
  /// в этот список не входят, поэтому повторного hoverEntered из них не будет — зациклиться некому.
  /// После закрытия свайпом вверх (closedBySwipe) не досылаем: иначе курсор у верха острова
  /// раскрывал бы его обратно в тот же момент. Флаг снимается, когда курсор уходит с острова
  static func shouldReenterHover(surface: Surface, pointerInside: Bool, closedBySwipe: Bool = false) -> Bool {
    guard pointerInside, !closedBySwipe else { return false }
    switch surface {
    // компакт календаря тоже покой: иначе после уведомления поверх календаря
    // остров остаётся закрытым под курсором
    case .idle, .compact, .peek, .calendar, .calendarPeek: return true
    default: return false
    }
  }
}
