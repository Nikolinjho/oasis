import IslandCore
import SwiftUI

/// Форма острова с анимируемыми размером, радиусом и ушками. Верх прижат к краю рамки, по центру
public struct IslandShape: Shape {
  public var size: CGSize
  public var bottomRadius: CGFloat
  public var shoulder: CGFloat

  /// shoulder задаётся, чтобы обрезать контент по телу острова без ушек (0)
  public init(spec: IslandShapeSpec, shoulder: CGFloat? = nil) {
    size = spec.size
    bottomRadius = spec.bottomRadius
    self.shoulder = shoulder ?? spec.shoulder
  }

  public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
    get { AnimatablePair(AnimatablePair(size.width, size.height), AnimatablePair(bottomRadius, shoulder)) }
    set {
      size = CGSize(width: newValue.first.first, height: newValue.first.second)
      bottomRadius = newValue.second.first
      // пружина с перелётом может увести ушко ниже нуля на пути к покою
      shoulder = max(newValue.second.second, 0)
    }
  }

  public func path(in rect: CGRect) -> Path {
    let outline = IslandOutline.path(size: size, bottomRadius: bottomRadius, shoulder: shoulder)
    return Path(outline).offsetBy(dx: rect.midX - size.width / 2 - shoulder, dy: rect.minY)
  }
}
