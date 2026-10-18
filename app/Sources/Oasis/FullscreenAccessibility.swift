import ApplicationServices
import CoreGraphics

/// macOS может оставить полосу выреза вне полноэкранного окна. AX отличает его от развёрнутого.
enum FullscreenAccessibility {
  // swiftlint:disable force_cast - CF-типы проверены через CFGetTypeID перед приведением
  static func isFullscreen(pid: pid_t?, ownPID: pid_t, screen: CGRect, topInset: CGFloat) -> Bool {
    guard let pid, pid != ownPID, AXIsProcessTrusted() else { return false }
    let application = AXUIElementCreateApplication(pid)
    guard AXUIElementSetMessagingTimeout(application, 0.15) == .success else { return false }
    guard let value = attribute(kAXFocusedWindowAttribute as CFString, of: application),
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return false }
    let window = value as! AXUIElement
    guard AXUIElementSetMessagingTimeout(window, 0.15) == .success else { return false }
    guard attribute("AXFullScreen" as CFString, of: window) as? Bool == true,
      let position = attribute(kAXPositionAttribute as CFString, of: window), CFGetTypeID(position) == AXValueGetTypeID(),
      let size = attribute(kAXSizeAttribute as CFString, of: window), CFGetTypeID(size) == AXValueGetTypeID()
    else { return false }
    var origin = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
      AXValueGetValue(size as! AXValue, .cgSize, &dimensions)
    else { return false }
    let bounds = CGRect(origin: origin, size: dimensions)
    return abs(bounds.minX - screen.minX) <= 1 && abs(bounds.width - screen.width) <= 1
      && abs(bounds.maxY - screen.maxY) <= 1 && bounds.minY >= screen.minY - 1
      && bounds.minY <= screen.minY + topInset + 2
  }
  // swiftlint:enable force_cast

  private static func attribute(_ name: CFString, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
  }
}
