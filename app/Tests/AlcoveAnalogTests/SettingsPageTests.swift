import Testing
@testable import AlcoveAnalog

@MainActor
struct SettingsPageTests {
    @Test("Сайдбар в порядке Alcove, готова только General, остальные — заглушки Soon")
    func sidebar() {
        #expect(SettingsPage.allCases.map(\.title) == [
            "General", "Battery", "Connectivity", "Focus", "Display", "Sound",
            "Now Playing", "Calendar", "File Tray", "Lock Screen", "About",
        ])
        #expect(SettingsPage.allCases.filter(\.isAvailable) == [.general, .battery, .connectivity, .display, .sound])
        #expect(SettingsPage.battery.group == "Notifications")
        #expect(SettingsPage.lockScreen.group == "Live Activities")
        #expect(SettingsPage.about.group == "Alcove")
        #expect(SettingsPage.general.group == nil)
    }

    @Test("Значение слайдера — одна цифра после точки и единица")
    func sliderValue() {
        #expect(SliderRow.format(0, unit: "s") == "0.0 s")
        #expect(SliderRow.format(0.3, unit: "s") == "0.3 s")
    }

    @Test("Пилюля слайдера: секунды с десятыми, целые pt, проценты без пробела (ui-inspection 1.3)")
    func sliderFormats() {
        #expect(SliderFormat.decimal("s").text(5) == "5.0 s")
        #expect(SliderFormat.integer("pt").text(-2) == "-2 pt")
        #expect(SliderFormat.integer("pt").text(0) == "0 pt")
        #expect(SliderFormat.percent.text(0.2) == "20%")
        #expect(SliderFormat.percent.text(0.1) == "10%")
    }

    @Test("Шаг слайдера: мусор Double-арифметики срезается, значение встаёт на ближайший шаг")
    func snapping() {
        #expect(SliderFormat.snap(0.30000000000000004, step: 0.1) == 0.3)
        #expect(SliderFormat.snap(2.74, step: 0.5) == 2.5)
        #expect(SliderFormat.snap(2.76, step: 0.5) == 3)
        #expect(SliderFormat.snap(-1.6, step: 1) == -2)
        #expect(SliderFormat.snap(0.19999, step: 0.1) == 0.2)
    }
}
