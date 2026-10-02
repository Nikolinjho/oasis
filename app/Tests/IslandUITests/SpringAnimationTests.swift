import IslandCore
import SwiftUI
import Testing

@testable import IslandUI

struct SpringAnimationTests {
  @Test(
    "Spring из SwiftUI идёт той же кривой, что замеренная пружина",
    arguments: [
      SpringSpec(stiffness: 175, damping: 16),
      SpringSpec(stiffness: 200, damping: 17.5),
      SpringSpec(stiffness: 185, damping: 27.5),
      .smooth(duration: 0.4),
    ])
  func sameCurve(spec: SpringSpec) {
    let spring = Spring(mass: 1, stiffness: spec.stiffness, damping: spec.damping, allowOverDamping: true)
    for step in 1...40 {
      let t = Double(step) / 50
      // SpringSpec.progress считает ζ > 1 критическим затуханием, SwiftUI — честным пережатием:
      // у 185/27.5 (ζ = 1.01) расхождение до 0.5% хода, у interpolatingSpring было то же самое
      let tolerance = spec.dampingRatio > 1 ? 0.006 : 1e-3
      #expect(abs(spring.value(target: 1.0, time: t) - spec.progress(at: t)) < tolerance, "t = \(t)")
    }
  }
}
