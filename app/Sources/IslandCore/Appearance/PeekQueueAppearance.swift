import CoreGraphics
import Foundation

public enum PeekQueueStyle: String, CaseIterable, Sendable {
  case row, capsule
}

public enum PeekQueuePosition: String, CaseIterable, Sendable {
  case left, right
}

public struct PeekQueueAppearance: Equatable, Sendable {
  public var style: PeekQueueStyle
  public var position: PeekQueuePosition

  public init(style: PeekQueueStyle = .row, position: PeekQueuePosition = .left) {
    self.style = style
    self.position = position
  }
}

/// Общая геометрия отрисовки и приёма кликов. Координаты идут вниз от верха окна.
public enum PeekQueueGeometry {
  public static let rowHeight: CGFloat = 26
  public static let capsuleSize = CGSize(width: 56, height: 28)
  public static let gap: CGFloat = 8

  public static func isVisible(surface: Surface, count: Int) -> Bool {
    guard count > 0 else { return false }
    switch surface {
    case .idle, .compact, .peek, .calendar, .calendarPeek, .hud, .alert: return true
    case .expanded, .hover, .hoverNudge, .shrink, .tuning: return false
    }
  }

  public static func islandSpec(_ content: IslandShapeSpec, appearance: PeekQueueAppearance, visible: Bool) -> IslandShapeSpec {
    var result = content
    if visible, appearance.style == .row {
      result.size.height += rowHeight
      result.bottomRadius = IslandGeometry.bottomRadius(forHeight: result.size.height)
    }
    return result
  }

  public static func indicatorFrame(content: IslandShapeSpec, appearance: PeekQueueAppearance, windowWidth: CGFloat) -> CGRect {
    if appearance.style == .row {
      return CGRect(
        x: (windowWidth - content.size.width) / 2 + 14, y: content.size.height,
        width: content.size.width - 28, height: rowHeight)
    }
    let edge = (content.size.width / 2) + content.shoulder + gap
    let x = appearance.position == .left ? windowWidth / 2 - edge - capsuleSize.width : windowWidth / 2 + edge
    return CGRect(x: x, y: 2, width: capsuleSize.width, height: capsuleSize.height)
  }

  public static func contains(
    _ point: CGPoint, content: IslandShapeSpec, appearance: PeekQueueAppearance,
    visible: Bool, windowWidth: CGFloat
  ) -> Bool {
    let spec = islandSpec(content, appearance: appearance, visible: visible)
    var transform = CGAffineTransform(translationX: (windowWidth - spec.size.width) / 2 - spec.shoulder, y: 0)
    let outline = IslandOutline.path(size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder)
    if outline.copy(using: &transform)?.contains(point) == true { return true }
    guard visible, appearance.style == .capsule else { return false }
    let frame = indicatorFrame(content: content, appearance: appearance, windowWidth: windowWidth)
    return CGPath(roundedRect: frame, cornerWidth: frame.height / 2, cornerHeight: frame.height / 2, transform: nil).contains(point)
  }
}
