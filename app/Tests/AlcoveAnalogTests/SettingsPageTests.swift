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
        #expect(SettingsPage.allCases.filter(\.isAvailable) == [.general])
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
}
