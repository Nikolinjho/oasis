import Testing

@testable import IslandCore

struct BackdropLuminanceTests {
  static func pixels(_ value: UInt8, count: Int = 4) -> [UInt8] {
    Array(repeating: [value, value, value, 255], count: count).flatMap { $0 }
  }

  @Test("Чёрный фон тёмный, белый и 50% серый — нет")
  func grayscale() {
    #expect(BackdropLuminance.isDark(rgba: Self.pixels(0)))
    #expect(!BackdropLuminance.isDark(rgba: Self.pixels(255)))
    #expect(!BackdropLuminance.isDark(rgba: Self.pixels(128)))
  }

  @Test("Яркость по весам Rec. 709: зелёный светлее синего")
  func weights() {
    #expect(abs(BackdropLuminance.mean(rgba: [0, 255, 0, 255]) - 0.7152) < 1e-9)
    #expect(abs(BackdropLuminance.mean(rgba: [0, 0, 255, 255]) - 0.0722) < 1e-9)
    #expect(BackdropLuminance.isDark(rgba: [0, 0, 255, 255]))
    #expect(!BackdropLuminance.isDark(rgba: [0, 255, 0, 255]))
  }

  @Test("Порог 0.35: средняя по всем пикселям, половина чёрного и половина белого — светлый фон")
  func meanAcrossPixels() {
    #expect(!BackdropLuminance.isDark(rgba: Self.pixels(0, count: 2) + Self.pixels(255, count: 2)))
    #expect(BackdropLuminance.isDark(rgba: Self.pixels(0, count: 3) + Self.pixels(255, count: 1)))
    #expect(!BackdropLuminance.isDark(rgba: Self.pixels(0, count: 3) + Self.pixels(255, count: 1), threshold: 0.2))
  }

  @Test("Пустой снимок не тёмный и не светлый: считаем тёмным, кант остаётся")
  func emptyIsDark() {
    #expect(BackdropLuminance.isDark(rgba: []))
  }
}
