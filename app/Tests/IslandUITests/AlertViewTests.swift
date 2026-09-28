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
        let notch = CGSize(width: 186, height: 32)
        for (name, alert) in [("alert-low-battery", IslandAlert.lowBattery(level: 0.1)), ("alert-low-power", .lowPower(level: 0.4))] {
            let size = IslandGeometry.size(for: alert, notch: notch)
            let view = ZStack(alignment: .top) {
                IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: 10.5), shoulder: 0)
                    .fill(IslandPalette.background)
                AlertView(alert: alert, notchWidth: notch.width)
            }
            try Snapshot.write(view, size: size, name: name)
        }
    }

    static func labelWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    @Test(
        "Подпись Low Battery и Low Power целиком умещается в левом крыле при любом вырезе: ширина считается от notch",
        arguments: [185, 186, 210] as [CGFloat]
    )
    func lowAlertLabelFitsLeftWing(notchWidth: CGFloat) {
        let notch = CGSize(width: notchWidth, height: 32)
        let cases: [(label: String, alert: IslandAlert)] = [
            ("Low Battery", .lowBattery(level: 0.1)),
            ("Low Power Mode", .lowPower(level: 0.4)),
        ]
        for (label, alert) in cases {
            let width = IslandGeometry.size(for: alert, notch: notch).width
            let leftWing = (width - notchWidth) / 2
            #expect(Self.labelWidth(label) + BatteryAlertView.padding <= leftWing)
        }
    }

    @Test("Подпись Charging умещается в левом крыле при вырезе по умолчанию: ширина измерена, не от notch")
    func chargingLabelFitsDefaultNotch() {
        let notchWidth: CGFloat = 186
        let width = IslandGeometry.size(for: .charging(level: 0.51), notch: CGSize(width: notchWidth, height: 32)).width
        let leftWing = (width - notchWidth) / 2
        #expect(Self.labelWidth("Charging") + BatteryAlertView.padding <= leftWing)
    }
}
