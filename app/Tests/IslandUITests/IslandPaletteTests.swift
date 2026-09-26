import AppKit
import SwiftUI
import Testing
@testable import IslandUI

@Test("Фон острова тёплый, а не чисто чёрный")
func backgroundIsWarm() throws {
    let color = try #require(NSColor(IslandPalette.background).usingColorSpace(.sRGB))
    #expect(color.redComponent > color.blueComponent)
    #expect(color.redComponent > 0)
}
