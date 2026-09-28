import Foundation
import IslandCore
import Testing
@testable import AlcoveAnalog

@MainActor
struct SoundPlayerTests {
    @Test("Звук ищется в Resources/Sounds бандла по имени из IslandSound")
    func url() {
        let resources = URL(fileURLWithPath: "/Apps/AlcoveAnalog.app/Contents/Resources")
        #expect(SoundPlayer.url(for: .lowBattery, resources: resources).path
            == "/Apps/AlcoveAnalog.app/Contents/Resources/Sounds/low-battery.caf")
        #expect(SoundPlayer.url(for: .event, resources: resources).lastPathComponent == "event.caf")
    }
}
