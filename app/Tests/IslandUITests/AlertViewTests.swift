import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct AlertViewTests {
    @Test("Процент заряда округляется и зажимается в 0…100")
    func percent() {
        #expect(ChargingView.percent(0.514) == "51%")
        #expect(ChargingView.percent(1) == "100%")
        #expect(ChargingView.percent(1.2) == "100%")
        #expect(ChargingView.percent(-0.1) == "0%")
    }

    @MainActor
    @Test("Снимок Charging")
    func snapshot() throws {
        let view = ZStack(alignment: .top) {
            IslandShape(spec: IslandShapeSpec(size: IslandGeometry.charging, bottomRadius: 10.5), shoulder: 0)
                .fill(IslandPalette.background)
            AlertView(alert: .charging(level: 0.51), notchWidth: 186)
        }
        try Snapshot.write(view, size: IslandGeometry.charging, name: "alert-charging")
    }
}
