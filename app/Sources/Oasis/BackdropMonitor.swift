import AppKit
import CoreGraphics
import IslandCore
import os

/// Contrast outline: тёмный ли фон под раскрытым островом. Alcove берёт яркость из CABackdropLayer
/// (backdropLayer:didChangeLuma:), мы снимаем полосы 16 pt вокруг формы из-под окна острова
/// (.optionOnScreenBelowWindow). Только если доступ к записи экрана уже выдан: запрос не показываем,
/// без доступа фон считаем тёмным — кант всегда, на светлом фоне поверх тени он почти не виден
/// (решение 03.10). Замер при раскрытии и раз в 2 с, пока раскрыт
@MainActor
final class BackdropMonitor {
  /// Снимок прямоугольника (координаты CG) из-под окна с данным id
  typealias Capture = (CGRect, CGWindowID) -> CGImage?

  static let strip: CGFloat = 16
  static let interval: TimeInterval = 2

  private let store: IslandStore
  private let hasAccess: () -> Bool
  private let capture: Capture
  private weak var panel: NSWindow?
  private var timer: Timer?

  init(
    store: IslandStore, hasAccess: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
    capture: @escaping Capture = BackdropMonitor.windowListImage
  ) {
    self.store = store
    self.hasAccess = hasAccess
    self.capture = capture
  }

  /// Смена surface: раскрыт и кант включён — замер сразу и по таймеру, иначе таймер гасим
  func update(panel: NSWindow?) {
    self.panel = panel
    guard measureNow() else {
      timer?.invalidate()
      timer = nil
      return
    }
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, !self.measureNow() else { return }
        self.timer?.invalidate()
        self.timer = nil
      }
    }
  }

  /// false — замерять нечего: остров не раскрыт или кант выключен
  private func measureNow() -> Bool {
    guard let panel, store.model.surface == .expanded, store.appearance.contrastOutline,
      let primary = NSScreen.screens.first
    else { return false }
    let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
    measure(island: island, windowID: CGWindowID(panel.windowNumber), primaryHeight: primary.frame.height)
    return true
  }

  /// island — форма в координатах AppKit. Нет доступа или снимка — тёмный
  func measure(island: CGRect, windowID: CGWindowID, primaryHeight: CGFloat) {
    guard hasAccess() else {
      store.backdropDark = true
      return
    }
    var pixels: [UInt8] = []
    for rect in Self.strips(around: island, primaryHeight: primaryHeight) {
      guard let image = capture(rect, windowID) else { continue }
      pixels += Self.rgba(image)
    }
    let dark = BackdropLuminance.isDark(rgba: pixels)
    if store.backdropDark != dark { store.backdropDark = dark }
  }

  /// Полосы слева, справа и снизу от формы в координатах CG: начало — левый верхний угол главного экрана
  static func strips(around island: CGRect, primaryHeight: CGFloat) -> [CGRect] {
    let appKit = [
      CGRect(x: island.minX - strip, y: island.minY, width: strip, height: island.height),
      CGRect(x: island.maxX, y: island.minY, width: strip, height: island.height),
      CGRect(x: island.minX - strip, y: island.minY - strip, width: island.width + 2 * strip, height: strip),
    ]
    return appKit.map { CGRect(x: $0.minX, y: primaryHeight - $0.maxY, width: $0.width, height: $0.height) }
  }

  /// Пиксели RGBA8 снимка, уменьшенного до 64 px по длинной стороне: для средней яркости хватает
  static func rgba(_ image: CGImage) -> [UInt8] {
    let scale = min(1, 64 / CGFloat(max(image.width, image.height, 1)))
    let width = max(1, Int(CGFloat(image.width) * scale))
    let height = max(1, Int(CGFloat(image.height) * scale))
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    return drawn ? bytes : []
  }

  private typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

  /// CGWindowListCreateImage в SDK macOS 15+ помечен obsoleted, но в системе есть: берём через dlsym.
  /// Не нашёлся — снимков нет, фон тёмный
  nonisolated(unsafe) private static let createImage: CreateImage? = {
    guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
      let symbol = dlsym(handle, "CGWindowListCreateImage")
    else {
      Logger(subsystem: "dev.nikoko.oasis", category: "window").error("CGWindowListCreateImage unavailable")
      return nil
    }
    return unsafeBitCast(symbol, to: CreateImage.self)
  }()

  nonisolated static func windowListImage(_ rect: CGRect, below windowID: CGWindowID) -> CGImage? {
    createImage?(
      rect, CGWindowListOption.optionOnScreenBelowWindow.rawValue, windowID,
      CGWindowImageOption.nominalResolution.rawValue)?.takeRetainedValue()
  }
}
