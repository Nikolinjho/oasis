/// Calendar (ui-inspection 1.9, осмотр 03.10): как остров рисует календарь. Поведение — в CalendarRules и CalendarClock
public struct CalendarAppearance: Equatable, Sendable {
  /// Use calendar color: иконка и кольцо компакта в цвете календаря события, а не красные.
  /// Карточки Duo и календарного вида в цвете календаря всегда
  public var usesCalendarColor = false
  /// Use colored calendar indicator: полоска строки peek в цвете календаря, выкл — красная.
  /// У Alcove разницы на осмотре не видно; что это полоска, а не иконка, — вывод из умолчаний: на записи
  /// с включённым по умолчанию тумблером иконка peek красная, полоска в цвете календаря (ui-inspection 3.5)
  public var coloredIndicator = true
  /// Always show month view: правая колонка календарного вида — сетка месяца
  public var monthView = false
  /// Use event indicators: черточки под днями сетки месяца
  public var eventIndicators = false

  public init() {}
}
