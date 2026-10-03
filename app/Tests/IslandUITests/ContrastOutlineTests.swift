import AppKit
import IslandCore
import SwiftUI
import Testing

@testable import IslandUI

struct ContrastOutlineTests {
  @Test("Кант только у раскрытого, при включённой настройке и над тёмным фоном")
  func visibility() {
    #expect(ContrastOutline.isVisible(surface: .expanded, enabled: true, backdropDark: true))
    #expect(!ContrastOutline.isVisible(surface: .expanded, enabled: false, backdropDark: true))
    #expect(!ContrastOutline.isVisible(surface: .expanded, enabled: true, backdropDark: false))
    for surface in [Surface.idle, .compact, .peek, .hover, .calendar, .hud(.volume, level: 0.5)] {
      #expect(!ContrastOutline.isVisible(surface: surface, enabled: true, backdropDark: true), "\(surface)")
    }
  }

  @MainActor
  @Test("Кант 1.5 pt снаружи формы, белый 10%, внутри формы — чёрная заливка")
  func outerHalfOnly() throws {
    let spec = IslandShapeSpec(size: CGSize(width: 200, height: 100), bottomRadius: 30)
    let size = CGSize(width: 240, height: 120)
    let view = ContrastOutline(spec: spec).frame(width: size.width, height: size.height, alignment: .top)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.cgImage)
    let bitmap = NSBitmapImageRep(cgImage: image)
    // под серединой нижнего края: 100 pt — край формы, 1 pt ниже — кант, 2 pt ниже — пусто
    func alpha(_ y: CGFloat) -> CGFloat { bitmap.colorAt(x: Int(size.width), y: Int(y * 2))?.alphaComponent ?? 0 }
    func white(_ y: CGFloat) -> CGFloat { bitmap.colorAt(x: Int(size.width), y: Int(y * 2))?.brightnessComponent ?? 0 }
    #expect(abs(alpha(100.75) - 0.10) < 0.03)
    #expect(alpha(102.25) < 0.01)
    // внутри формы заливка закрывает внутреннюю половину штриха
    #expect(alpha(99.25) > 0.99 && white(99.25) < 0.01)
  }
}
