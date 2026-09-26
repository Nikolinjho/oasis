import Foundation

/// Пружина с массой 1. Та же модель, что в capture/tools/springfit.py и в SwiftUI interpolatingSpring,
/// поэтому замеры переносятся без пересчёта
public struct SpringSpec: Equatable, Sendable {
    public let stiffness: Double
    public let damping: Double

    public init(stiffness: Double, damping: Double) {
        self.stiffness = stiffness
        self.damping = damping
    }

    /// SwiftUI .smooth(duration:): критическое затухание
    public static func smooth(duration: Double) -> SpringSpec {
        let omega = 2 * Double.pi / duration
        return SpringSpec(stiffness: omega * omega, damping: 2 * omega)
    }

    /// SwiftUI .spring(duration:bounce:) для bounce от 0 до 1
    public static func spring(duration: Double, bounce: Double) -> SpringSpec {
        let omega = 2 * Double.pi / duration
        return SpringSpec(stiffness: omega * omega, damping: 2 * (1 - bounce) * omega)
    }

    public var dampingRatio: Double { damping / (2 * stiffness.squareRoot()) }

    /// Доля пройденного пути в момент t: 0 в начале, 1 у цели
    public func progress(at t: Double) -> Double {
        let w0 = stiffness.squareRoot()
        let z = dampingRatio
        if z < 1 {
            let wd = w0 * (1 - z * z).squareRoot()
            return 1 - exp(-z * w0 * t) * (cos(wd * t) + z * w0 / wd * sin(wd * t))
        }
        return 1 - exp(-w0 * t) * (1 + w0 * t)
    }

    /// Перелёт в долях хода
    public var overshoot: Double {
        let z = dampingRatio
        guard z < 1 else { return 0 }
        return exp(-z * Double.pi / (1 - z * z).squareRoot())
    }

    /// Момент, после которого отклонение от цели не превышает tolerance хода
    public func settlingTime(tolerance: Double = 0.01) -> Double {
        let step = 1.0 / 1000
        var last = 0.0
        var t = 0.0
        while t < 3 {
            if abs(1 - progress(at: t)) > tolerance { last = t }
            t += step
        }
        return last + step
    }
}
