import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct HUDViewTests {
    @Test("Иконка громкости по уровню")
    func volumeSymbols() {
        #expect(HUDView.symbol(.volume, 0) == "speaker.slash.fill")
        #expect(HUDView.symbol(.volume, 0.2) == "speaker.wave.1.fill")
        #expect(HUDView.symbol(.volume, 0.5) == "speaker.wave.2.fill")
        #expect(HUDView.symbol(.volume, 0.9) == "speaker.wave.3.fill")
    }

    @Test("Иконка яркости по уровню")
    func brightnessSymbols() {
        #expect(HUDView.symbol(.brightness, 0.3) == "sun.min.fill")
        #expect(HUDView.symbol(.brightness, 0.8) == "sun.max.fill")
    }

    @MainActor
    @Test("Снимок HUD громкости")
    func snapshot() throws {
        let view = ZStack(alignment: .top) {
            IslandShape(spec: IslandShapeSpec(size: IslandGeometry.hud, bottomRadius: 10), shoulder: 0)
                .fill(IslandPalette.background)
            HUDView(kind: .volume, level: 0.5, notchWidth: 186)
        }
        try Snapshot.write(view, size: IslandGeometry.hud, name: "hud-volume")
    }
}
