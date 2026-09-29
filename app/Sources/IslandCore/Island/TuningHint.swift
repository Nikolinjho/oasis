/// Значение ползунка General → Tuning, которое остров подсказывает красной подложкой, пока
/// ползунок зажат (Task 17t, по образцу Alcove 1.7.9). value — то же pt, что в SliderRow (−2…2)
public enum TuningHint: Equatable, Sendable {
    /// Notch width
    case width(Int)
    /// Notch height
    case height(Int)

    public var value: Int {
        switch self {
        case let .width(value), let .height(value): value
        }
    }

    /// Значение со знаком и типографским минусом: «−1», «+0», «+2» (Alcove 1.7.9, 29.09 — так подписан
    /// height-подсказка «+0»; у width-подсказки видели только «−1», знак «+» на нуле и положительных — по аналогии)
    public var signedLabel: String {
        value < 0 ? "\u{2212}\(-value)" : "+\(value)"
    }

    /// Строка width-подсказки: «← −1 →» (Alcove 1.7.9, 29.09, MBP 16", Notch width −1)
    public var arrowLabel: String {
        "\u{2190} \(signedLabel) \u{2192}"
    }
}
