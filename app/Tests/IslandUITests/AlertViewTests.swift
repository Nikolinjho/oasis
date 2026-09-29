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
            let size = IslandGeometry.size(for: alert, notch: notch, reminderIndicatorWidth: 0)
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
            let width = IslandGeometry.size(for: alert, notch: notch, reminderIndicatorWidth: 0).width
            let leftWing = (width - notchWidth) / 2
            #expect(Self.labelWidth(label) + BatteryAlertView.padding <= leftWing)
        }
    }

    @Test("Подпись Charging умещается в левом крыле при вырезе по умолчанию: ширина измерена, не от notch")
    func chargingLabelFitsDefaultNotch() {
        let notchWidth: CGFloat = 186
        let width = IslandGeometry.size(for: .charging(level: 0.51), notch: CGSize(width: notchWidth, height: 32), reminderIndicatorWidth: 0).width
        let leftWing = (width - notchWidth) / 2
        #expect(Self.labelWidth("Charging") + BatteryAlertView.padding <= leftWing)
    }

    @MainActor
    @Test("Снимок напоминания за 15 минут")
    func reminderSnapshot() throws {
        let notch = CGSize(width: 186, height: 32)
        let alert = IslandAlert.calendarReminder(CalendarReminder(eventID: "fake-remind", title: "Fake Call", minutes: 15, color: RGB(red: 0.2, green: 0.5, blue: 1)))
        let size = IslandGeometry.size(for: alert, notch: notch, reminderIndicatorWidth: IslandView.reminderIndicatorWidth)
        let view = ZStack(alignment: .top) {
            IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: IslandGeometry.bottomRadius(forHeight: size.height)), shoulder: 0)
                .fill(IslandPalette.background)
            AlertView(alert: alert, notchWidth: notch.width)
                .frame(width: size.width, height: size.height, alignment: .top)
        }
        try Snapshot.write(view, size: size, name: "alert-calendar-reminder")
    }

    @Test("Пол ширины напоминания меряется по «15m», самому широкому индикатору напоминания")
    func reminderIndicatorWidth() {
        #expect(IslandView.reminderIndicatorWidth == ActivityCompactView.indicatorWidth(.text("15m", color: ActivityLayouts.calendarRed)))
        // с Alcove 1.7.9 (29.09) у компакта календаря тоже «15m» — самый широкий индикатор при открытии окна
        // при музыке, поэтому полы теперь совпадают
        #expect(IslandView.reminderIndicatorWidth == IslandView.calendarIndicatorWidth)
    }

    @MainActor
    @Test("Снимки AirPods: полное и почти пустое кольцо")
    func airpodsSnapshots() throws {
        let notch = CGSize(width: 186, height: 32)
        let cases: [(String, IslandAlert)] = [
            ("alert-airpods-full", .airpods(AirPodsInfo(name: "AirPods Pro", battery: 1))),
            ("alert-airpods-low", .airpods(AirPodsInfo(name: "AirPods", battery: 0.15))),
        ]
        for (name, alert) in cases {
            let size = IslandGeometry.size(for: alert, notch: notch, reminderIndicatorWidth: IslandView.reminderIndicatorWidth)
            let view = ZStack(alignment: .top) {
                IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: 10.5), shoulder: 0)
                    .fill(IslandPalette.background)
                AlertView(alert: alert, notchWidth: notch.width)
            }
            try Snapshot.write(view, size: size, name: name)
        }
    }

    @Test("Кольцо AirPods умещается в правом крыле при любом вырезе", arguments: [186, 240, 300] as [CGFloat])
    func airpodsRingFitsWing(notchWidth: CGFloat) {
        let alert = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 1))
        let width = IslandGeometry.size(for: alert, notch: CGSize(width: notchWidth, height: 32), reminderIndicatorWidth: IslandView.reminderIndicatorWidth).width
        let wing = (width - notchWidth) / 2
        let ring = ActivityCompactView.indicatorWidth(ActivityLayouts.airpods(AirPodsInfo(name: "AirPods Pro", battery: 1)).indicator)
        #expect(ring + ActivityLayout.compactPadding <= wing)
        #expect(ActivityLayout.iconWidth + ActivityLayout.compactPadding <= wing)
    }
}
