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
    /// Промежуточное состояние при наведении
    case hover
    /// Раскрытый плеер
    case expanded
    /// Сжатие почти до выреза перед сменой активности
    case shrink
    case hud(HUDKind, level: Double)
}
