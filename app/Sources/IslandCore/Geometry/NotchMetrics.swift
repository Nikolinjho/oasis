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
      safeAreaTop > 0, right.minX > left.maxX
    else { return nil }
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

/// General → Tuning (Notch width / Notch height у Alcove, −2…2, ui-inspection 1.2): сдвиг в pt к размеру
/// выреза по API. У Alcove на этой машине −2: 185 → тело в покое 183 (ui-inspection 3.1)
public struct NotchTuning: Equatable, Sendable {
  public var width: CGFloat
  public var height: CGFloat

  public init(width: CGFloat = 0, height: CGFloat = 0) {
    self.width = width
    self.height = height
  }
}

extension NotchMetrics {
  /// Вырез со сдвигом. Экран тот же, поэтому notchRect остаётся по центру и у верхнего края
  public func tuned(by tuning: NotchTuning) -> NotchMetrics {
    NotchMetrics(
      notchSize: CGSize(
        width: max(1, notchSize.width + tuning.width),
        height: max(1, notchSize.height + tuning.height)),
      screenFrame: screenFrame)
  }
}
