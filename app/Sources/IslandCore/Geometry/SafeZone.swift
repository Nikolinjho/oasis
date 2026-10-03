import CoreGraphics

extension IslandGeometry {
  /// Безопасная зона hover раскрытого: курсор ушёл с формы, а остров не закрывается. Есть у Alcove
  /// независимо от блюра, с блюром шире (ui-inspection §1.2, замер программным курсором 03.10, шаг 5–10 pt)
  public struct SafeZone: Equatable, Sendable {
    /// Запас влево и вправо от формы
    public var side: CGFloat
    /// Запас вниз от формы. Вверх запаса нет: выше края экрана курсор не бывает
    public var bottom: CGFloat

    public init(side: CGFloat, bottom: CGFloat) {
      self.side = side
      self.bottom = bottom
    }

    /// Замер Alcove 03.10: без Progressive blur
    public static let plain = SafeZone(side: 15, bottom: 32)
    /// Замер Alcove 03.10: с Progressive blur
    public static let blurred = SafeZone(side: 35, bottom: 35)

    /// Прямоугольник в координатах экрана (y вверх), расширенный в стороны и вниз
    public func expanding(_ rect: CGRect) -> CGRect {
      CGRect(x: rect.minX - side, y: rect.minY - bottom, width: rect.width + 2 * side, height: rect.height + bottom)
    }
  }

  /// Зона вокруг формы раскрытого для текущей настройки Progressive blur
  public static func safeZone(around rect: CGRect, blur: Bool) -> CGRect {
    (blur ? SafeZone.blurred : .plain).expanding(rect)
  }
}
