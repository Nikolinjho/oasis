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

  @Test("Маска: непрозрачно у края формы, половина на 42.5 pt, ноль с 85 pt — вниз и в стороны")
  func maskFade() throws {
    let image = try #require(VariableBlurMask.image(size: Self.size, shape: Self.shape, fade: 85))
    #expect(image.width == 624 && image.height == 320)
    let midX = Self.shape.midX
    #expect(Self.alpha(image, midX, 100) == 1)
    #expect(Self.alpha(image, midX, 175) > 0.98)
    #expect(abs(Self.alpha(image, midX, 217) - 0.5) < 0.02)
    // smoothstep: у края блюр держится дольше линейного, к концу уходит быстрее
    #expect(Self.alpha(image, midX, 205) > 0.7)
    #expect(Self.alpha(image, midX, 230) < 0.3)
    #expect(Self.alpha(image, midX, 260) == 0)
    // сбоку то же: половина на 42.5 pt левее формы, ноль с 85 pt
    #expect(abs(Self.alpha(image, Self.shape.minX - 43, 50) - 0.5) < 0.02)
    #expect(Self.alpha(image, Self.shape.minX - 86, 50) == 0)
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
  @Test("Без материала или фильтра вид пустой и не падает")
  func missingPrivateAPI() {
    let noView = VariableBlurFactory(makeEffectView: { nil }, makeFilter: { NSObject() })
    let noFilter = VariableBlurFactory(makeEffectView: { NSView() }, makeFilter: { nil })
    for factory in [noView, noFilter] {
      let view = VariableBlurHostView(factory: factory)
      view.frame = CGRect(origin: .zero, size: Self.size)
      view.update(shape: Self.shape, fade: 80)
      view.layout()
      #expect(view.blurLayer == nil)
      #expect(view.subviews.isEmpty)
      #expect(view.frame.size == Self.size)
    }
  }

  /// Подставной фильтр: KVC в словарь и копирование, как у CAFilter
  final class FakeFilter: NSObject, NSCopying {
    var values: [String: Any] = [:]
    override func setValue(_ value: Any?, forKey key: String) { values[key] = value }
    override func value(forKey key: String) -> Any? { values[key] }
    func copy(with zone: NSZone? = nil) -> Any {
      let copy = FakeFilter()
      copy.values = values
      return copy
    }
  }

  /// Подставной backdrop: поиск идёт по имени класса
  final class FakeBackdropLayer: CALayer {}

  @MainActor
  @Test("Фильтр ставится на backdrop-слой материала, тинт и цвет материала прячутся")
  func adoptsBackdrop() throws {
    let root = CALayer()
    let container = CALayer()
    let backdrop = FakeBackdropLayer()
    let tint = CALayer()
    let fill = CALayer()
    container.addSublayer(backdrop)
    container.addSublayer(tint)
    root.addSublayer(container)
    root.addSublayer(fill)
    let filter = NSMutableDictionary()
    let found = try #require(VariableBlurHostView.adopt(root: root, filters: [filter]))
    #expect(found === backdrop)
    #expect((backdrop.value(forKey: "filters") as? [Any])?.count == 1)
    #expect(tint.isHidden && fill.isHidden)
    #expect(!container.isHidden && !backdrop.isHidden)
    #expect(VariableBlurHostView.adopt(root: CALayer(), filters: [filter]) == nil)
  }

  @MainActor
  @Test("С фабрикой материал на весь вид, радиус 1 и маска в фильтре")
  func filterConfigured() throws {
    let filter = FakeFilter()
    let root = NSView()
    root.wantsLayer = true
    root.layer?.addSublayer(FakeBackdropLayer())
    let factory = VariableBlurFactory(makeEffectView: { root }, makeFilter: { filter })
    let view = VariableBlurHostView(factory: factory)
    view.frame = CGRect(origin: .zero, size: Self.size)
    view.update(shape: Self.shape, fade: 80)
    view.layout()
    #expect(root.frame == view.bounds)
    #expect(view.blurLayer is FakeBackdropLayer)
    #expect(filter.values["inputRadius"] as? CGFloat == 1)
    // маска уходит в копию фильтра на слое: тот же объект с новой маской CA не перечитывает
    let applied = try #require((view.blurLayer?.value(forKey: "filters") as? [Any])?.first as? FakeFilter)
    #expect(applied !== filter && applied.values["inputMaskImage"] != nil)
  }

  @Test("Форма для маски — раскрытый с ушками по центру окна у верха")
  func blurShapeInWindow() {
    let spec = IslandShapeSpec(size: CGSize(width: 345, height: 175), bottomRadius: 35, shoulder: 18.3)
    let rect = IslandView.blurShape(spec, width: 624)
    #expect(abs(rect.minX - 121.2) < 1e-9 && abs(rect.width - 381.6) < 1e-9)
    #expect(rect.minY == 0 && rect.height == 175)
  }
}
