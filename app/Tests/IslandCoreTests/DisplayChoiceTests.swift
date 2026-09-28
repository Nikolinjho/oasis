import Testing
@testable import IslandCore

struct DisplayChoiceTests {
    @Test("Выбор экрана сохраняется строкой и читается обратно")
    func roundTrip() {
        for choice in [DisplayChoice.main, .named("DELL U2723QE"), .named("Built-in Retina Display")] {
            #expect(DisplayChoice(storageValue: choice.storageValue) == choice)
        }
    }

    @Test("Пустое и незнакомое значение читается как главный экран")
    func unknownIsMain() {
        #expect(DisplayChoice(storageValue: nil) == .main)
        #expect(DisplayChoice(storageValue: "") == .main)
        #expect(DisplayChoice(storageValue: "all") == .main)
    }
}
