import Testing
@testable import IslandSources

struct LevelStepTests {
    @Test("Обычный шаг 1/16 с прилипанием к сетке")
    func regularStep() {
        #expect(LevelStep.apply(0.5, up: true, fine: false) == 0.5625)
        #expect(LevelStep.apply(0.51, up: true, fine: false) == 0.5625)
        #expect(LevelStep.apply(0.5, up: false, fine: false) == 0.4375)
    }

    @Test("Уровень не выходит за 0…1")
    func clamped() {
        #expect(LevelStep.apply(1, up: true, fine: false) == 1)
        #expect(LevelStep.apply(0, up: false, fine: false) == 0)
    }

    @Test("С Option+Shift шаг 1/64")
    func fineStep() {
        #expect(LevelStep.apply(0.5, up: true, fine: true) == 0.515625)
    }
}
