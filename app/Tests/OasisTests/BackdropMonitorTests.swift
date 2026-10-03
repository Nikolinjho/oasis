import CoreGraphics
import Testing

@testable import Oasis

@MainActor
struct BackdropMonitorTests {
  @Test("Полосы 16 pt слева, справа и снизу от формы, в координатах CG (y вниз от верха главного экрана)")
  func strips() {
    // форма у верха экрана высотой 1117: y 942…1117 в координатах AppKit
    let island = CGRect(x: 673, y: 942, width: 382, height: 175)
    let strips = BackdropMonitor.strips(around: island, primaryHeight: 1117)
    #expect(strips[0] == CGRect(x: 657, y: 0, width: 16, height: 175))
    #expect(strips[1] == CGRect(x: 1055, y: 0, width: 16, height: 175))
    #expect(strips[2] == CGRect(x: 657, y: 175, width: 414, height: 16))
  }

  @Test("Без доступа к записи экрана снимков нет, фон считается тёмным, доступ не запрашивается")
  func noAccessMeansDark() {
    let store = IslandStore(config: .alcove)
    store.backdropDark = false
    var captures = 0
    let monitor = BackdropMonitor(
      store: store, hasAccess: { false },
      capture: { _, _ in
        captures += 1
        return nil
      })
    monitor.measure(island: CGRect(x: 0, y: 0, width: 10, height: 10), windowID: 1, primaryHeight: 100)
    #expect(store.backdropDark)
    #expect(captures == 0)
  }

  @Test("Снимок светлых полос гасит кант, тёмных — показывает")
  func capturedLuminance() throws {
    let store = IslandStore(config: .alcove)
    for (white, dark) in [(CGFloat(1), false), (0, true)] {
      let image = try #require(Self.solid(white: white))
      let monitor = BackdropMonitor(store: store, hasAccess: { true }, capture: { _, _ in image })
      monitor.measure(island: CGRect(x: 0, y: 0, width: 10, height: 10), windowID: 1, primaryHeight: 100)
      #expect(store.backdropDark == dark)
    }
  }

  static func solid(white: CGFloat) -> CGImage? {
    let context = CGContext(
      data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    context?.setFillColor(CGColor(gray: white, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    return context?.makeImage()
  }
}
