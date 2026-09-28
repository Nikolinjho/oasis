import AppKit
import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct AlertViewTests {
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

    @Test("Процент Low Battery: округление и зажим в 0…100")
    func percent() {
        #expect(BatteryAlertView.percent(0.104) == "10%")
        #expect(BatteryAlertView.percent(1.3) == "100%")
        #expect(BatteryAlertView.percent(-0.1) == "0%")
    }

    @MainActor
    @Test("Снимки Low Battery и Low Power")
    func lowSnapshots() throws {
        for (name, alert) in [("alert-low-battery", IslandAlert.lowBattery(level: 0.1)), ("alert-low-power", .lowPower(level: 0.4))] {
            let size = IslandGeometry.size(for: alert)
            let view = ZStack(alignment: .top) {
                IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: 10.5), shoulder: 0)
                    .fill(IslandPalette.background)
                AlertView(alert: alert, notchWidth: 186)
            }
            try Snapshot.write(view, size: size, name: name)
        }
    }

    @Test("Подпись Charging, Low Battery и Low Power целиком умещается в левом крыле выреза")
    func labelFitsLeftWing() {
        let notchWidth: CGFloat = 186
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        func labelWidth(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        let cases: [(label: String, alert: IslandAlert)] = [
            ("Charging", .charging(level: 0.51)),
            ("Low Battery", .lowBattery(level: 0.1)),
            ("Low Power Mode", .lowPower(level: 0.4)),
        ]
        for (label, alert) in cases {
            let width = IslandGeometry.size(for: alert).width
            let leftWing = (width - notchWidth) / 2
            #expect(labelWidth(label) + 14 <= leftWing)
        }
    }
}
