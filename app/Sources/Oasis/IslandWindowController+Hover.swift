import AppKit
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

extension IslandWindowController {
  /// Разбор события scrollWheel для SwipeTracker. Инерцию не берём: у Alcove её нет. Колесо мыши
  /// (без точных дельт) не трогаем. Касание (mayBegin) и прочие фазы — nil. Ось (вертикаль или горизонталь)
  /// решает трекер. Знак зависит от General → Gestures → Natural movement (natural): вкл (по умолчанию) —
  /// как в записи жестов, пальцы вниз дают dy > 0 при включённой системной натуральной прокрутке (inverted),
  /// и наоборот при выключенной. Natural movement выкл — жест всегда читается как прокрутка контента:
  /// системная inverted не учитывается, знак тот же, что у natural: true, inverted: false

  static func swipeInput(  // swiftlint:disable:this function_parameter_count - поля NSEvent плюс две настройки
    phase: NSEvent.Phase, momentumPhase: NSEvent.Phase, precise: Bool,
    deltaX: CGFloat, deltaY: CGFloat, inverted: Bool, natural: Bool = true
  ) -> SwipeInput? {
    guard precise, momentumPhase.isEmpty else { return nil }
    // Natural movement вкл: знак от устройства, пальцы вниз — dy > 0 при любой системной прокрутке.
    // Выкл: как прокрутка контента — с натуральной прокруткой направление обратное
    let sign: CGFloat = natural && inverted ? 1 : -1
    let trackerPhase: SwipeTracker.Phase
    switch phase {
    case .began: trackerPhase = .began
    case .changed: trackerPhase = .changed
    case .ended: trackerPhase = .ended
    case .cancelled: trackerPhase = .cancelled
    default: return nil
    }
    guard trackerPhase == .changed else { return SwipeInput(phase: trackerPhase, dx: 0, dy: 0) }
    return SwipeInput(phase: .changed, dx: sign * deltaX, dy: sign * deltaY)
  }
}
