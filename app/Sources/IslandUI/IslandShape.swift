import IslandCore
import SwiftUI

/// Форма острова с анимируемыми размером и радиусом. Верх прижат к краю рамки, по центру
public struct IslandShape: Shape {
    public var size: CGSize
    public var bottomRadius: CGFloat
    public var shoulder: CGFloat

    public init(spec: IslandShapeSpec, shoulder: CGFloat = IslandGeometry.shoulder) {
        size = spec.size
        bottomRadius = spec.bottomRadius
        self.shoulder = shoulder
    }

    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(size.width, size.height), bottomRadius) }
        set {
            size = CGSize(width: newValue.first.first, height: newValue.first.second)
            bottomRadius = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let outline = IslandOutline.path(size: size, bottomRadius: bottomRadius, shoulder: shoulder)
        return Path(outline).offsetBy(dx: rect.midX - size.width / 2 - shoulder, dy: rect.minY)
    }
}
