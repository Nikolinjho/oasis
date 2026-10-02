import CoreGraphics
import Foundation

/// Разбирает SVG-путь из Squircle в CGPath. Поддерживает только то, что выдаёт порт: M, L, c, a, Z
public enum SVGPath {
  public static func cgPath(_ svg: String) -> CGPath {
    let tokens = svg.split(separator: " ").map(String.init)
    let path = CGMutablePath()
    var index = 0
    var current = CGPoint.zero
    var start = CGPoint.zero

    func number() -> CGFloat {
      defer { index += 1 }
      return CGFloat(Double(tokens[index])!)
    }

    while index < tokens.count {
      let command = tokens[index]
      index += 1
      switch command {
      case "M":
        current = CGPoint(x: number(), y: number())
        start = current
        path.move(to: current)
      case "L":
        current = CGPoint(x: number(), y: number())
        path.addLine(to: current)
      case "c":
        let c1 = CGPoint(x: current.x + number(), y: current.y + number())
        let c2 = CGPoint(x: current.x + number(), y: current.y + number())
        let end = CGPoint(x: current.x + number(), y: current.y + number())
        path.addCurve(to: end, control1: c1, control2: c2)
        current = end
      case "a":
        let radius = number()
        _ = number()  // ry, у squircle равен rx
        _ = number()  // поворот эллипса, всегда 0
        let largeArc = number() != 0
        let sweep = number() != 0
        let end = CGPoint(x: current.x + number(), y: current.y + number())
        appendArc(to: path, from: current, to: end, radius: radius, largeArc: largeArc, sweep: sweep)
        current = end
      case "Z":
        path.closeSubpath()
        current = start
      default:
        preconditionFailure("SVGPath: неподдерживаемая команда \(command)")
      }
    }
    return path
  }

  /// Дуга окружности по конечным точкам (SVG 1.1, F.6.5, rx = ry, без поворота), кубиками по ≤ 90°
  static func appendArc(  // swiftlint:disable:this function_parameter_count - параметры дуги по SVG 1.1
    to path: CGMutablePath, from p1: CGPoint, to p2: CGPoint, radius: CGFloat, largeArc: Bool, sweep: Bool
  ) {
    let x1p = (p1.x - p2.x) / 2
    let y1p = (p1.y - p2.y) / 2
    var r = radius
    let lambda = (x1p * x1p + y1p * y1p) / (r * r)
    if lambda > 1 { r *= lambda.squareRoot() }

    let numerator = r * r * r * r - r * r * y1p * y1p - r * r * x1p * x1p
    let denominator = r * r * y1p * y1p + r * r * x1p * x1p
    var coefficient = denominator == 0 ? 0 : max(0, numerator / denominator).squareRoot()
    if largeArc == sweep { coefficient = -coefficient }
    let center = CGPoint(
      x: coefficient * y1p + (p1.x + p2.x) / 2,
      y: -coefficient * x1p + (p1.y + p2.y) / 2)

    let startAngle = atan2(p1.y - center.y, p1.x - center.x)
    var delta = atan2(p2.y - center.y, p2.x - center.x) - startAngle
    if sweep, delta < 0 { delta += 2 * .pi }
    if !sweep, delta > 0 { delta -= 2 * .pi }

    let parts = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
    let step = delta / CGFloat(parts)
    let k = 4 / 3 * tan(step / 4)
    var angle = startAngle
    for _ in 0..<parts {
      let next = angle + step
      let from = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
      let to = CGPoint(x: center.x + r * cos(next), y: center.y + r * sin(next))
      let c1 = CGPoint(x: from.x - k * r * sin(angle), y: from.y + k * r * cos(angle))
      let c2 = CGPoint(x: to.x + k * r * sin(next), y: to.y - k * r * cos(next))
      path.addCurve(to: to, control1: c1, control2: c2)
      angle = next
    }
  }
}
