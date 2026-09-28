import Foundation

/// Тайминги острова из motion/motion.md и capture/analysis/README.md
public enum IslandTiming {
    /// Peek с названием трека держится 2 с
    public static let quickPeek: Duration = .seconds(2)
    /// HUD скрывается через 1.5 с после последнего изменения
    public static let hudVisible: Duration = .milliseconds(1500)
    /// Уведомление держится 5 с: Duration по умолчанию на странице Battery (ui-inspection 1.3)
    public static let alertVisible: Duration = .seconds(5)
    /// Сжатие перед сменой активности
    public static let shrink: Duration = .milliseconds(330)
    /// Peek календаря держится 4.2 с: Peek duration 4 с, замер ui-inspection 3.5
    public static let calendarPeek: Duration = .milliseconds(4200)
    /// Отклик на hover перед раскрытием в плеер. Обзорное видео Alcove, 30 fps: форма подрастает
    /// 4 кадра (≈ 130 мс) после касания курсором, на 5-м начинается раскрытие
    public static let hoverNudge: Duration = .milliseconds(130)
    /// Задержка схлопывания после ухода курсора. То же видео: курсор ушёл, схлопывание видно
    /// через 4–5 кадров (133–167 мс), берём 150
    public static let hoverLeave: Duration = .milliseconds(150)

    /// Вход и выход контента: проявление из размытия и угасание, без сжатия по X
    public static let slotIn: Double = 0.3
    public static let slotOut: Double = 0.25
    public static let slotInBlur: CGFloat = 10
    public static let slotOutBlur: CGFloat = 4

    /// Скорость бегущей строки в peek, pt/с
    public static let marqueeSpeed: CGFloat = 30
    /// Периоды полосок эквалайзера, высота пульса 3 → 12 pt
    public static let equalizerPeriods: [Double] = [0.95, 1.46, 0.82, 1.24]
}
