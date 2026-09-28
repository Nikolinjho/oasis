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
}
