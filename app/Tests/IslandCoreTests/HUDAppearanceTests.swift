import Testing

@testable import IslandCore

struct HUDAppearanceTests {
  @Test("Decibel: цвет по уровню — зелёный, оранжевый, красный (оценка без замера, решение 28.09)")
  func decibel() {
    #expect(HUDBarStyle.decibelColor(level: 0.5) == HUDBarStyle.decibelGreen)
    #expect(HUDBarStyle.decibelColor(level: 0.6) == HUDBarStyle.decibelOrange)
    #expect(HUDBarStyle.decibelColor(level: 0.7) == HUDBarStyle.decibelOrange)
    #expect(HUDBarStyle.decibelColor(level: 0.85) == HUDBarStyle.decibelRed)
    #expect(HUDBarStyle.decibelOrange == RGB(red: 0xE4 / 255, green: 0x91 / 255, blue: 0x6A / 255))
  }

  @Test("По умолчанию как у Alcove: громкость Decibel с глифом устройства, яркость Accent, Fast, без процента")
  func defaults() {
    let appearance = IslandAppearance.default
    #expect(appearance.hud(.volume) == HUDAppearance(style: .decibel, icon: .device))
    #expect(appearance.hud(.brightness) == HUDAppearance(style: .accent))
    #expect(appearance.hud(.volume).speed == .fast)
    #expect(!appearance.hud(.brightness).showsPercentage)
  }
}
