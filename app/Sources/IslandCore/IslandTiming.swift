import Foundation

/// Тайминги острова из motion/motion.md и capture/analysis/README.md
public enum IslandTiming {
    /// Peek с названием трека держится 2 с
    public static let quickPeek: Duration = .seconds(2)
    /// HUD скрывается через 1.5 с после последнего изменения
    public static let hudVisible: Duration = .milliseconds(1500)
    /// Сжатие перед сменой активности
    public static let shrink: Duration = .milliseconds(330)
    /// Схлопывание раскрытого острова
    public static let collapse: Duration = .milliseconds(400)

    /// Вход и выход бокового контента: проявление из размытия со сжатием по X
    public static let slotIn: Double = 0.3
    public static let slotOut: Double = 0.25
    public static let slotInBlur: CGFloat = 10
    public static let slotOutBlur: CGFloat = 4
    public static let slotOutScaleX: CGFloat = 0.25

    /// Скорость бегущей строки в peek, pt/с
    public static let marqueeSpeed: CGFloat = 30
    /// Периоды полосок эквалайзера, высота пульса 3 → 12 pt
    public static let equalizerPeriods: [Double] = [0.95, 1.46, 0.82, 1.24]
}
