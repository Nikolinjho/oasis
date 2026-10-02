import Foundation

/// Порт squircle с сайта Alcove (site/pretty/squircle-CJT0V4zl.js): кривая squircle, preserveSmoothing.
/// Только общий случай, без веток для «пилюли». Выдаёт SVG-путь в тех же числах, что оригинал
public enum Squircle {
  public struct Radii: Equatable, Sendable {
    public var topLeft: Double
    public var topRight: Double
    public var bottomRight: Double
    public var bottomLeft: Double

    public init(topLeft: Double, topRight: Double, bottomRight: Double, bottomLeft: Double) {
      self.topLeft = topLeft
      self.topRight = topRight
      self.bottomRight = bottomRight
      self.bottomLeft = bottomLeft
    }
  }

  public static func svgPath(width w: Double, height h: Double, radii: Radii, smoothing: Double = 0.65) -> String {
    let budgets = cornerBudgets(radii, width: w, height: h)
    let tl = corner(budgets.topLeft, smoothing)
    let tr = corner(budgets.topRight, smoothing)
    let br = corner(budgets.bottomRight, smoothing)
    let bl = corner(budgets.bottomLeft, smoothing)

    var s = "M \(f(tl.p)) 0 L \(f(w - tr.p)) 0"
    s += segment(tr, .topRight)
    s += " L \(f(w)) \(f(br.p)) L \(f(w)) \(f(h - br.p))"
    s += segment(br, .bottomRight)
    s += " L \(f(w - bl.p)) \(f(h)) L \(f(bl.p)) \(f(h))"
    s += segment(bl, .bottomLeft)
    s += " L 0 \(f(h - tl.p)) L 0 \(f(tl.p))"
    s += segment(tl, .topLeft)
    return s + " Z"
  }

  // MARK: - Бюджет углов (функции t и e оригинала)

  struct Budget {
    var radius: Double
    var budget: Double
  }

  struct Budgets {
    var topLeft: Budget
    var topRight: Budget
    var bottomRight: Budget
    var bottomLeft: Budget
  }

  /// Сколько места угол может занять вдоль сторон с учётом соседей
  static func adjacentBudget(  // swiftlint:disable:this function_parameter_count - сигнатура как в формуле Alcove
    _ r: Double, _ adjacentR: Double, _ adjacentBudget: Double, _ w: Double,
    _ oppositeR: Double, _ oppositeBudget: Double, _ h: Double
  ) -> Double {
    let horizontal =
      r == 0 && adjacentR == 0
      ? 0
      : adjacentBudget >= 0 ? w - adjacentBudget : r / (r + adjacentR) * w
    let vertical =
      r == 0 && oppositeR == 0
      ? 0
      : oppositeBudget >= 0 ? h - oppositeBudget : r / (r + oppositeR) * h
    return min(horizontal, vertical)
  }

  static func cornerBudgets(_ r: Radii, width w: Double, height h: Double) -> Budgets {
    if r.topLeft == r.topRight, r.topRight == r.bottomRight, r.bottomRight == r.bottomLeft,
      r.topLeft > 0, w > 0, h > 0
    {
      let half = min(w, h) / 2
      let b = Budget(radius: min(r.topLeft, half), budget: half)
      return Budgets(topLeft: b, topRight: b, bottomRight: b, bottomLeft: b)
    }
    // обход от меньших радиусов к большим, как в оригинале
    let rankTL = (r.topRight > r.topLeft ? 1 : 0) + (r.bottomLeft > r.topLeft ? 1 : 0) + (r.bottomRight > r.topLeft ? 1 : 0)
    let rankTR = (r.topLeft >= r.topRight ? 1 : 0) + (r.bottomLeft > r.topRight ? 1 : 0) + (r.bottomRight > r.topRight ? 1 : 0)
    let rankBL = (r.topLeft >= r.bottomLeft ? 1 : 0) + (r.topRight >= r.bottomLeft ? 1 : 0) + (r.bottomRight > r.bottomLeft ? 1 : 0)

    var tl = r.topLeft
    var tr = r.topRight
    var bl = r.bottomLeft
    var br = r.bottomRight
    var bTL = -1.0
    var bTR = -1.0
    var bBL = -1.0
    var bBR = -1.0
    for v in 0..<4 {
      if rankTL == v {
        bTL = adjacentBudget(r.topLeft, tr, bTR, w, bl, bBL, h)
        tl = min(r.topLeft, bTL)
      } else if rankTR == v {
        bTR = adjacentBudget(r.topRight, tl, bTL, w, br, bBR, h)
        tr = min(r.topRight, bTR)
      } else if rankBL == v {
        bBL = adjacentBudget(r.bottomLeft, br, bBR, w, tl, bTL, h)
        bl = min(r.bottomLeft, bBL)
      } else {
        bBR = adjacentBudget(r.bottomRight, bl, bBL, w, tr, bTR, h)
        br = min(r.bottomRight, bBR)
      }
    }
    return Budgets(
      topLeft: Budget(radius: tl, budget: bTL),
      topRight: Budget(radius: tr, budget: bTR),
      bottomRight: Budget(radius: br, budget: bBR),
      bottomLeft: Budget(radius: bl, budget: bBL))
  }

  // MARK: - Параметры угла (функция c оригинала)

  struct Corner {
    var a = 0.0, b = 0.0, c = 0.0, d = 0.0
    /// Сколько угол занимает вдоль каждой стороны
    var p = 0.0
    var arc = 0.0
    var radius = 0.0
  }

  static func corner(_ budget: Budget, _ smoothing: Double) -> Corner {
    let r = budget.radius
    guard r > 0 else { return Corner() }
    var p = (1 + smoothing) * r
    let arcMeasure = 90 * (1 - smoothing)
    let arc = sin(radians(arcMeasure / 2)) * r * 2.0.squareRoot()
    let angleAlpha = (90 - arcMeasure) / 2
    let p3ToP4 = r * tan(radians(angleAlpha / 2))
    let angleBeta = 45 * smoothing
    let c = p3ToP4 * cos(radians(angleBeta))
    let d = c * tan(radians(angleBeta))
    var b = (p - arc - c - d) / 3
    var a = 2 * b
    if p > budget.budget {
      let p1ToP3 = budget.budget - d - arc - c
      let limit = p1ToP3 - p1ToP3 / 6
      b = min(b, limit)
      a = p1ToP3 - b
      p = min(p, budget.budget)
    }
    return Corner(a: a, b: b, c: c, d: d, p: p, arc: arc, radius: r)
  }

  // MARK: - Сегменты углов (функции u, d, f, p оригинала)

  enum Position {
    case topRight, bottomRight, bottomLeft, topLeft
  }

  static func segment(_ k: Corner, _ position: Position) -> String {
    guard k.radius > 0 else { return "" }
    let (a, b, c, d, r, s) = (k.a, k.b, k.c, k.d, k.radius, k.arc)
    let body =
      switch position {
      case .topRight:
        "c \(f(a)) 0 \(f(a + b)) 0 \(f(a + b + c)) \(f(d)) a \(f(r)) \(f(r)) 0 0 1 \(f(s)) \(f(s)) c \(f(d)) \(f(c)) \(f(d)) \(f(b + c)) \(f(d)) \(f(a + b + c))"
      case .bottomRight:
        "c 0 \(f(a)) 0 \(f(a + b)) \(f(-d)) \(f(a + b + c)) a \(f(r)) \(f(r)) 0 0 1 -\(f(s)) \(f(s)) c \(f(-c)) \(f(d)) \(f(-(b + c))) \(f(d)) \(f(-(a + b + c))) \(f(d))"
      case .bottomLeft:
        "c \(f(-a)) 0 \(f(-(a + b))) 0 \(f(-(a + b + c))) \(f(-d)) a \(f(r)) \(f(r)) 0 0 1 -\(f(s)) -\(f(s)) c \(f(-d)) \(f(-c)) \(f(-d)) \(f(-(b + c))) \(f(-d)) \(f(-(a + b + c)))"
      case .topLeft:
        "c 0 \(f(-a)) 0 \(f(-(a + b))) \(f(d)) \(f(-(a + b + c))) a \(f(r)) \(f(r)) 0 0 1 \(f(s)) -\(f(s)) c \(f(c)) \(f(-d)) \(f(b + c)) \(f(-d)) \(f(a + b + c)) \(f(-d))"
      }
    return " " + body
  }

  static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

  /// toFixed(4) из JS
  static func f(_ x: Double) -> String { String(format: "%.4f", x) }
}
