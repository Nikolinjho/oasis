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

/// Подложка и фильтр. Фабрики внедряются: тесты проверяют, что nil не роняет вид
struct VariableBlurFactory {
  var makeEffectView: () -> NSView?
  var makeFilter: () -> NSObject?

  /// Радиус у края. Подгонка по снимкам 2x над полосатой подложкой (03.10): перепад яркости соседних пикселей
  /// под краем, +60, +110 и +170 px у Alcove 14 / 25 / 97 / 174, у нас 13 / 30 / 88 / 174 (в шкале Alcove).
  /// Фильтр считает радиус не в pt: 16 размывал полосы 20 pt в сплошной цвет
  static let radius: CGFloat = 1

  /// CABackdropLayer, созданный вручную внутри SwiftUI-хоста, содержимого под окном не получает (живая проверка
  /// 03.10). Его получает только NSVisualEffectView с .behindWindow: у неё берём её же backdrop-слой
  /// и меняем гауссов блюр материала на variableBlur
  @MainActor static let system = VariableBlurFactory(
    makeEffectView: {
      let view = BlurEffectView()
      view.blendingMode = .behindWindow
      view.state = .active
      view.material = .hudWindow
      return view
    },
    makeFilter: {
      let selector = NSSelectorFromString("filterWithType:")
      guard let type = NSClassFromString("CAFilter") as? NSObject.Type, type.responds(to: selector) else { return nil }
      return type.perform(selector, with: "variableBlur")?.takeUnretainedValue() as? NSObject
    })

  /// Подложка с фильтром или nil (одна запись в лог за запуск)
  @MainActor
  func make() -> (view: NSView, filter: NSObject)? {
    guard let filter = makeFilter(), let view = makeEffectView() else {
      VariableBlurLog.unavailable("no effect view or variableBlur filter")
      return nil
    }
    filter.setValue(Self.radius, forKey: "inputRadius")
    filter.setValue(true, forKey: "inputNormalizeEdges")
    return (view, filter)
  }
}

@MainActor
enum VariableBlurLog {
  private static var logged = false

  static func unavailable(_ reason: String) {
    guard !logged else { return }
    logged = true
    Logger(subsystem: "dev.nikoko.oasis", category: "blur").error("variableBlur unavailable: \(reason, privacy: .public)")
  }
}

/// Материал, который сообщает о своей раскладке: после неё его backdrop-слой уже есть
final class BlurEffectView: NSVisualEffectView {
  var onLayout: () -> Void = {}

  override func layout() {
    super.layout()
    onLayout()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    // слои материала появляются в той же транзакции, что и окно: следующий проход главной очереди
    DispatchQueue.main.async { [weak self] in self?.onLayout() }
  }

  override func updateLayer() {
    super.updateLayer()
    onLayout()
  }
}

/// Хост подложки. Маска строится сверху вниз (строки CGImage), как координаты SwiftUI
final class VariableBlurHostView: NSView {
  private var effectView: NSView?
  private var filter: NSObject?
  /// Найденный backdrop-слой материала: nil, пока вид не в окне или подменить не удалось
  private(set) var blurLayer: CALayer?
  private var shape: CGRect = .zero
  private var fade: CGFloat = VariableBlurMask.fade
  private var mask: CGImage?
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
      effectView = made.view
      filter = made.filter
      made.view.autoresizingMask = [.width, .height]
      // материал строит и перестраивает свои слои сам, уже после нашей раскладки: подмена после каждой его
      (made.view as? BlurEffectView)?.onLayout = { [weak self] in self?.installFilter() }
      addSubview(made.view)
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
    installFilter()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    installFilter()
  }

  override func layout() {
    super.layout()
    effectView?.frame = bounds
    // материал может пересоздать свои фильтры при раскладке: подменяем каждый раз
    effectView?.layoutSubtreeIfNeeded()
    installFilter()
  }

  fileprivate func installFilter() {
    guard let effectView, let filter, bounds.size != .zero else { return }
    let key = MaskKey(size: bounds.size, shape: shape, fade: fade)
    if key != maskKey {
      mask = VariableBlurMask.image(size: bounds.size, shape: shape, fade: fade)
      maskKey = key
    }
    guard let mask, let root = effectView.layer else { return }
    // тот же объект фильтра с новой маской CA считает неизменным: каждый раз — свежая копия
    let current = filter.copy() as? NSObject ?? filter
    current.setValue(mask, forKey: "inputMaskImage")
    blurLayer = Self.adopt(root: root, filters: [current])
    if blurLayer == nil, window != nil { VariableBlurLog.unavailable("no backdrop layer in the effect view") }
  }

  /// Ищет в дереве слоёв материала backdrop-слой (класс CABackdropLayer и родня), ставит ему фильтры, а слои
  /// тинта и цвета материала прячет: иначе поверх блюра лежала бы серая плёнка. nil — backdrop нет
  static func adopt(root: CALayer, filters: [Any]) -> CALayer? {
    guard let backdrop = firstBackdrop(in: root) else { return nil }
    hideAll(in: root, except: backdrop)
    // материал снимает фон в 1/8 разрешения (scale 0.125) и растягивает: это само по себе ровный блюр
    // по всему окну, и маска фильтра на нём не видна. Полное разрешение — блюр только от variableBlur
    backdrop.setValue(1.0, forKey: "scale")
    backdrop.setValue(filters, forKey: "filters")
    return backdrop
  }

  static func isBackdrop(_ layer: CALayer) -> Bool {
    NSStringFromClass(type(of: layer)).contains("Backdrop")
  }

  private static func firstBackdrop(in layer: CALayer) -> CALayer? {
    if isBackdrop(layer) { return layer }
    for sublayer in layer.sublayers ?? [] {
      if let found = firstBackdrop(in: sublayer) { return found }
    }
    return nil
  }

  /// Прячет всё, что не backdrop и не его предок. Сам слой-корень материала тоже может рисовать фон
  private static func hideAll(in layer: CALayer, except backdrop: CALayer) {
    for sublayer in layer.sublayers ?? [] where sublayer !== backdrop {
      if firstBackdrop(in: sublayer) != nil {
        hideAll(in: sublayer, except: backdrop)
      } else {
        sublayer.isHidden = true
      }
    }
    if layer !== backdrop { layer.backgroundColor = nil }
  }
}

/// Маска силы блюра: 1 над формой и у её края, к 0 на расстоянии fade от формы по smoothstep. Линейный спад
/// давал слишком мягкую середину: у Alcove блюр держится у края и быстро уходит за ≈55 pt (подгонка 03.10)
enum VariableBlurMask {
  /// Замер Alcove 03.10: блюр исчезает к 70–90 pt, по профилю резкости — к 85
  static let fade: CGFloat = 85

  /// Расстояние от точки до прямоугольника, 0 внутри
  static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return (dx * dx + dy * dy).squareRoot()
  }

  static func alpha(distance: CGFloat, fade: CGFloat) -> CGFloat {
    guard fade > 0 else { return distance > 0 ? 0 : 1 }
    let t = min(distance / fade, 1)
    return 1 - t * t * (3 - 2 * t)
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
