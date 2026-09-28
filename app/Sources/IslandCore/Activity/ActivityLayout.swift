import CoreGraphics

/// Как выглядит компактная активность: иконка слева от выреза, индикатор справа, строка peek снизу.
/// Календарь, AirPods и свои модули описывают себя этим значением, рисует их ActivityCompactView.
/// Паттерн снят с календаря и AirPods Alcove (ui-inspection 3.5, 3.6)
public struct ActivityLayout: Equatable, Sendable {
    public enum Indicator: Equatable, Sendable {
        /// Кольцо прогресса на тёмном треке: время до события, ход события, заряд AirPods
        case ring(progress: Double, color: RGB, track: RGB)
        /// Короткий текст: секунды до начала события
        case text(String, color: RGB)
    }

    /// Строка peek под компактом: полоска цвета, название, иконка и текст справа
    public struct Line: Equatable, Sendable {
        public var bar: RGB?
        public var title: String
        public var trailingSymbol: String?
        public var trailing: String?

        public init(bar: RGB?, title: String, trailingSymbol: String? = nil, trailing: String? = nil) {
            self.bar = bar
            self.title = title
            self.trailingSymbol = trailingSymbol
            self.trailing = trailing
        }
    }

    /// SF Symbol иконки
    public var symbol: String
    public var symbolColor: RGB
    public var indicator: Indicator
    public var line: Line?

    public init(symbol: String, symbolColor: RGB, indicator: Indicator, line: Line? = nil) {
        self.symbol = symbol
        self.symbolColor = symbolColor
        self.indicator = indicator
        self.line = line
    }

    /// Паддинг компакта активности с каждой стороны выреза. Оценка по кадрам
    /// capture/analysis/ui-inspection/calendar-airpods/cal-snap-230346.png и cal-countdown.jpg
    /// (тело ~254 pt, иконка от края ~8 pt), замер ±1 pt. Общая константа для view, width и тестов,
    /// чтобы паддинг не разъехался по местам
    public static let compactPadding: CGFloat = 8
    /// Ширина иконки слева — совпадает с .frame(width:) иконки в ActivityCompactView
    public static let iconWidth: CGFloat = 18
    /// Диаметр кольца индикатора — совпадает с .frame кольца в ActivityCompactView
    public static let ringWidth: CGFloat = 16
    /// Кегль текстового индикатора (полужирный, моноширинные цифры). Оценка по высоте цифр в
    /// cal-countdown.jpg (~8.5 pt высоты у кегля 12), замер ±1 pt
    public static let indicatorFontSize: CGFloat = 12

    /// Ширина компакта под данный индикатор: крылья вокруг выреза симметричны, чтобы вырез остался
    /// по центру. Каждое крыло — паддинг compactPadding плюс большая из иконки (iconWidth) и индикатора;
    /// иначе индикатор шире иконки вылезает под вырез. indicatorWidth меряет вызывающая сторона
    /// (ActivityCompactView.indicatorWidth в IslandUI, кольцо — фиксированные 16).
    ///
    /// Alcove держит фиксированную ширину компакта (~254 pt на кадрах), это значение — только нижняя
    /// граница под длинные индикаторы вроде "15m"/"59m". Вызывающая сторона (IslandGeometry.calendarSize) должна брать
    /// max(измеренная фиксированная ширина, width(...)), а не одно только width(...)
    public static func width(notchWidth: CGFloat, indicatorWidth: CGFloat) -> CGFloat {
        notchWidth + 2 * (compactPadding + max(iconWidth, indicatorWidth))
    }
}
