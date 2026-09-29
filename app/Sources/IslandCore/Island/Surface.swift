public enum HUDKind: Hashable, Sendable {
    case volume, brightness
}

/// Что остров показывает прямо сейчас
public enum Surface: Equatable, Sendable {
    case idle
    /// Live activity музыки: обложка слева, волна справа
    case compact
    /// Компакт плюс строка с названием трека
    case peek
    /// Промежуточное состояние при наведении (режим Alcove): мини-остров 190×73 без контента
    case hover
    /// Отклик на наведение (режим пользователя): форма from чуть шире, контент тот же,
    /// по таймеру hoverOpen раскрывается в плеер. from — idle, compact, peek, calendar или calendarPeek
    indirect case hoverNudge(from: Surface)
    /// Раскрытый: по умолчанию Duo (плеер + повестка), полный плеер — свайпом (см. IslandView)
    case expanded
    /// Сжатие почти до выреза перед сменой активности
    case shrink
    case hud(HUDKind, level: Double)
    /// Уведомление: Charging, в P1 — батарея, AirPods, напоминания календаря
    case alert(IslandAlert)
    /// Компакт календаря: за 15 минут до начала (liveLead) события до его конца (Alcove 1.7.9, 29.09). Второй вид покоя
    case calendar
    /// Компакт календаря и строка с названием: старт события, 4.2 с
    case calendarPeek
}
