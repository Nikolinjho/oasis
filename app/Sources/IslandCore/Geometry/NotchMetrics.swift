import CoreGraphics

/// Вырез конкретного экрана. Координаты AppKit: начало снизу слева
public struct NotchMetrics: Equatable, Sendable {
    public var notchSize: CGSize
    public var screenFrame: CGRect

    public init(notchSize: CGSize, screenFrame: CGRect) {
        self.notchSize = notchSize
        self.screenFrame = screenFrame
    }

    /// Вырез — промежуток между auxiliaryTopLeftArea и auxiliaryTopRightArea, высота — safeAreaInsets.top
    public init?(screenFrame: CGRect, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?, safeAreaTop: CGFloat) {
        guard let left = auxiliaryTopLeft, let right = auxiliaryTopRight,
              safeAreaTop > 0, right.minX > left.maxX else { return nil }
        self.init(
            notchSize: CGSize(width: right.minX - left.maxX, height: safeAreaTop),
            screenFrame: screenFrame)
    }

    /// Вырез в координатах экрана
    public var notchRect: CGRect {
        CGRect(
            x: screenFrame.midX - notchSize.width / 2,
            y: screenFrame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height)
    }
}
