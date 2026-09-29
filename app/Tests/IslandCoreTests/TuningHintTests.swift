import Testing
@testable import IslandCore

/// Форматирование подписи подложки подгонки выреза (Task 17t, Alcove 1.7.9, 29.09)
struct TuningHintTests {
    @Test("Значение со знаком: типографский минус на отрицательных, «+» на нуле и положительных")
    func signedLabel() {
        #expect(TuningHint.width(-1).signedLabel == "\u{2212}1")
        #expect(TuningHint.height(0).signedLabel == "+0")
        #expect(TuningHint.height(2).signedLabel == "+2")
    }

    @Test("Строка width-подсказки: стрелки вокруг значения")
    func arrowLabel() {
        #expect(TuningHint.width(-1).arrowLabel == "\u{2190} \u{2212}1 \u{2192}")
    }

    @Test("value достаёт сырое число независимо от того, width это или height")
    func value() {
        #expect(TuningHint.width(-2).value == -2)
        #expect(TuningHint.height(2).value == 2)
    }
}
