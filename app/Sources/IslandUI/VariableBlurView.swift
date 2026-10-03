import AppKit
import SwiftUI
import os

/// Progressive blur Alcove (variableBlur): под раскрытым островом размывается то, что под окном, сильнее всего
/// у края формы, к 40 pt вдвое слабее, к 80 pt ноль (ui-inspection §1.2, осмотр 03.10). Приватные
/// CABackdropLayer и CAFilter — через рантайм: не нашлись — вид пустой, раскладка та же
struct VariableBlurView: NSViewRepresentable {
  /// Форма в координатах вида: y вниз от верха окна
  let shape: CGRect
  var fade: CGFloat = VariableBlurMask.fade
  var factory = VariableBlurFactory.system

  func makeNSView(context: Context) -> VariableBlurHostView {
    VariableBlurHostView(factory: factory)
  }

  func updateNSView(_ view: VariableBlurHostView, context: Context) {
    view.update(shape: shape, fade: fade)
  }
}

/// Слой-подложка с фильтром. Фабрики внедряются: тесты проверяют, что nil не роняет вид
struct VariableBlurFactory {
  var makeBackdrop: () -> CALayer?
  var makeFilter: () -> NSObject?

  /// Радиус у края, pt: оценка по кадрам Alcove 03.10
  static let radius: CGFloat = 16

  @MainActor static let system = VariableBlurFactory(
    makeBackdrop: {
      // backdrop, а не обычный слой: фильтр должен размывать содержимое под окном, а не слой острова
      guard let type = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return nil }
      let layer = type.init()
      // без этого backdrop видит только содержимое своего окна
      layer.setValue(true, forKey: "windowServerAware")
      return layer
    },
    makeFilter: {
      let selector = NSSelectorFromString("filterWithType:")
      guard let type = NSClassFromString("CAFilter") as? NSObject.Type, type.responds(to: selector) else { return nil }
      return type.perform(selector, with: "variableBlur")?.takeUnretainedValue() as? NSObject
    })

  /// Слой с фильтром или nil (одна запись в лог за запуск)
  @MainActor
  func make() -> (layer: CALayer, filter: NSObject)? {
    guard let layer = makeBackdrop(), let filter = makeFilter() else {
      Self.logUnavailableOnce()
      return nil
    }
    filter.setValue(Self.radius, forKey: "inputRadius")
    filter.setValue(true, forKey: "inputNormalizeEdges")
    return (layer, filter)
  }

  @MainActor private static var loggedUnavailable = false

  @MainActor
  private static func logUnavailableOnce() {
    guard !loggedUnavailable else { return }
    loggedUnavailable = true
    Logger(subsystem: "dev.nikoko.oasis", category: "blur").error("variableBlur unavailable: no backdrop layer or filter")
  }
}

/// Вид с перевёрнутой геометрией (y вниз): маска строится в тех же координатах, что SwiftUI и строки CGImage
final class VariableBlurHostView: NSView {
  private(set) var blurLayer: CALayer?
  private var filter: NSObject?
  private var shape: CGRect = .zero
  private var fade: CGFloat = VariableBlurMask.fade
  /// Размер, форма и спад, под которые построена текущая маска
  private var maskKey: MaskKey?

  private struct MaskKey: Equatable {
    let size: CGSize
    let shape: CGRect
    let fade: CGFloat
  }

  init(factory: VariableBlurFactory) {
    super.init(frame: .zero)
    wantsLayer = true
    if let made = factory.make() {
      blurLayer = made.layer
      filter = made.filter
      layer?.addSublayer(made.layer)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override var isFlipped: Bool { true }

  /// Клики и hover — острову: подложка их не ловит
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  func update(shape: CGRect, fade: CGFloat) {
    self.shape = shape
    self.fade = fade
    applyMask()
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    blurLayer?.frame = bounds
    CATransaction.commit()
    applyMask()
  }

  private func applyMask() {
    guard let blurLayer, let filter, bounds.size != .zero else { return }
    let key = MaskKey(size: bounds.size, shape: shape, fade: fade)
    guard key != maskKey, let mask = VariableBlurMask.image(size: bounds.size, shape: shape, fade: fade) else { return }
    maskKey = key
    filter.setValue(mask, forKey: "inputMaskImage")
    // фильтры слоя копируются при присваивании: новая маска доходит только через новое присваивание
    blurLayer.setValue([filter], forKey: "filters")
  }
}

/// Маска силы блюра: 1 над формой и у её края, линейно к 0 на расстоянии fade от формы
enum VariableBlurMask {
  /// Замер Alcove 03.10: к ≈40 pt слабее, к 70–90 pt исчезает
  static let fade: CGFloat = 80

  /// Расстояние от точки до прямоугольника, 0 внутри
  static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return (dx * dx + dy * dy).squareRoot()
  }

  static func alpha(distance: CGFloat, fade: CGFloat) -> CGFloat {
    fade > 0 ? max(0, 1 - distance / fade) : (distance > 0 ? 0 : 1)
  }

  /// RGBA8, 1 px на pt, строка 0 — верх вида. Белый с альфой: фильтр читает альфу
  static func image(size: CGSize, shape: CGRect, fade: CGFloat) -> CGImage? {
    let width = Int(size.width.rounded(.up))
    let height = Int(size.height.rounded(.up))
    guard width > 0, height > 0 else { return nil }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let center = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
        let value = UInt8((alpha(distance: distance(from: center, to: shape), fade: fade) * 255).rounded())
        let offset = (y * width + x) * 4
        // премультиплицированный белый: цвет равен альфе
        bytes[offset] = value
        bytes[offset + 1] = value
        bytes[offset + 2] = value
        bytes[offset + 3] = value
      }
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
    return CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
  }
}
