import AppKit
import CoreGraphics
import IslandCore
import Testing

@testable import IslandUI

struct VariableBlurTests {
  static let size = CGSize(width: 624, height: 320)
  /// Раскрытый с ушками по центру у верха окна
  static let shape = CGRect(x: 121.2, y: 0, width: 381.6, height: 175)

  /// Альфа пикселя маски в точке (x, y) вида: y вниз от верха, как строки CGImage
  static func alpha(_ image: CGImage, _ x: CGFloat, _ y: CGFloat) -> CGFloat {
    let data = image.dataProvider!.data! as Data
    let offset = Int(y) * image.bytesPerRow + Int(x) * image.bitsPerPixel / 8
    return CGFloat(data[offset + 3]) / 255
  }

  @Test("Маска: непрозрачно у края формы, около половины на 40 pt, ноль с 80 pt — вниз и в стороны")
  func maskFade() throws {
    let image = try #require(VariableBlurMask.image(size: Self.size, shape: Self.shape, fade: 80))
    #expect(image.width == 624 && image.height == 320)
    let midX = Self.shape.midX
    #expect(Self.alpha(image, midX, 100) == 1)
    #expect(Self.alpha(image, midX, 175) > 0.98)
    #expect(abs(Self.alpha(image, midX, 215) - 0.5) < 0.02)
    #expect(Self.alpha(image, midX, 255) < 0.02)
    #expect(Self.alpha(image, midX, 300) == 0)
    // сбоку: 40 pt левее формы — половина, 80 pt — ноль
    #expect(abs(Self.alpha(image, Self.shape.minX - 40, 50) - 0.5) < 0.02)
    #expect(Self.alpha(image, Self.shape.minX - 81, 50) == 0)
  }

  @Test("Альфа по расстоянию до формы: у угла считается по диагонали")
  func alphaByDistance() {
    #expect(VariableBlurMask.alpha(distance: 0, fade: 80) == 1)
    #expect(VariableBlurMask.alpha(distance: 40, fade: 80) == 0.5)
    #expect(VariableBlurMask.alpha(distance: 120, fade: 80) == 0)
    let corner = CGPoint(x: Self.shape.maxX + 30, y: Self.shape.maxY + 40)
    #expect(abs(VariableBlurMask.distance(from: corner, to: Self.shape) - 50) < 1e-9)
  }

  @MainActor
  @Test("Без CABackdropLayer или фильтра вид пустой и не падает")
  func missingPrivateAPI() {
    let noLayer = VariableBlurFactory(makeBackdrop: { nil }, makeFilter: { NSObject() })
    let noFilter = VariableBlurFactory(makeBackdrop: { CALayer() }, makeFilter: { nil })
    for factory in [noLayer, noFilter] {
      let view = VariableBlurHostView(factory: factory)
      view.frame = CGRect(origin: .zero, size: Self.size)
      view.update(shape: Self.shape, fade: 80)
      view.layout()
      #expect(view.blurLayer == nil)
      #expect(view.layer?.sublayers?.isEmpty ?? true)
      #expect(view.frame.size == Self.size)
    }
  }

  @MainActor
  @Test("С фабрикой слой на весь вид, радиус 16 и маска в фильтре")
  func filterConfigured() throws {
    let filter = NSMutableDictionary()
    let factory = VariableBlurFactory(makeBackdrop: { CALayer() }, makeFilter: { filter })
    let view = VariableBlurHostView(factory: factory)
    view.frame = CGRect(origin: .zero, size: Self.size)
    view.update(shape: Self.shape, fade: 80)
    view.layout()
    let layer = try #require(view.blurLayer)
    #expect(layer.frame == view.bounds)
    #expect(filter["inputRadius"] as? CGFloat == 16)
    #expect(filter["inputMaskImage"] != nil)
  }

  @Test("Форма для маски — раскрытый с ушками по центру окна у верха")
  func blurShapeInWindow() {
    let spec = IslandShapeSpec(size: CGSize(width: 345, height: 175), bottomRadius: 35, shoulder: 18.3)
    let rect = IslandView.blurShape(spec, width: 624)
    #expect(abs(rect.minX - 121.2) < 1e-9 && abs(rect.width - 381.6) < 1e-9)
    #expect(rect.minY == 0 && rect.height == 175)
  }
}
