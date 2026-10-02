import AppKit
import SwiftUI
import Testing

@testable import IslandUI

@Test("Фон острова чисто чёрный, как у нативного Alcove: форма сливается с вырезом")
func backgroundIsBlack() throws {
  let color = try #require(NSColor(IslandPalette.background).usingColorSpace(.sRGB))
  #expect(color.redComponent == 0)
  #expect(color.greenComponent == 0)
  #expect(color.blueComponent == 0)
}
