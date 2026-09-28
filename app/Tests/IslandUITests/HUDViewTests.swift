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
            HUDView(kind: .volume, level: 0.5, notchWidth: 185, appearance: IslandAppearance.default.hud(.volume),
                    deviceSymbol: "airpodspro")
        }
        try Snapshot.write(view, size: IslandGeometry.hud, name: "hud-volume")
    }

    @Test("Иконка громкости: глиф устройства по настройке, без звука — перечёркнутый динамик, яркость — солнце")
    func iconSymbol() {
        let device = HUDAppearance(style: .decibel, icon: .device)
        let symbol = HUDAppearance(style: .decibel, icon: .symbol)
        #expect(HUDView.iconSymbol(.volume, 0.5, device, deviceSymbol: "airpodspro") == "airpodspro")
        #expect(HUDView.iconSymbol(.volume, 0, device, deviceSymbol: "airpodspro") == "speaker.slash.fill")
        #expect(HUDView.iconSymbol(.volume, 0.5, symbol, deviceSymbol: "airpodspro") == "speaker.wave.2.fill")
        #expect(HUDView.iconSymbol(.brightness, 0.8, device, deviceSymbol: "airpodspro") == "sun.max.fill")
    }

    @Test("Полоска уже, когда рядом процент — по крылу выреза 185 и широкого 211")
    func barWidth() {
        let narrow = HUDView.wingWidth(notchWidth: 185)
        #expect(narrow == 77)
        #expect(HUDView.barWidth(HUDAppearance(style: .white), wing: narrow) == 64)
        #expect(HUDView.barWidth(HUDAppearance(style: .white, showsPercentage: true), wing: narrow) == 35)

        let wide = HUDView.wingWidth(notchWidth: 211)
        #expect(wide == 64)
        #expect(HUDView.barWidth(HUDAppearance(style: .white), wing: wide) == 64)
        #expect(HUDView.barWidth(HUDAppearance(style: .white, showsPercentage: true), wing: wide) == 22)

        #expect(HUDView.percent(0.456) == "46%")
    }

    @Test("Процент с полоской не выходит за крыло: «100%» (36) + зазор 6 + полоска ≤ крыла")
    func percentGroupFitsWing() {
        for notchWidth: CGFloat in [185, 187] {
            let wing = HUDView.wingWidth(notchWidth: notchWidth)
            let bar = HUDView.barWidth(HUDAppearance(style: .white, showsPercentage: true), wing: wing)
            #expect(36 + 6 + bar <= wing)
        }
    }
}
