import Testing

@testable import IslandCore

struct SpringSpecTests {
  @Test(".smooth(0.4) совпадает с замером схлопывания 250/32")
  func smoothMatchesMeasuredCollapse() {
    let spring = SpringSpec.smooth(duration: 0.4)
    #expect(abs(spring.stiffness - 246.7) < 0.5)
    #expect(abs(spring.damping - 31.4) < 0.1)
    #expect(abs(spring.dampingRatio - 1) < 1e-9)
  }

  @Test(".spring(0.45, bounce 0.1) близка к замеру раскрытия в HUD 190/24.5")
  func springMatchesMeasuredGrow() {
    let spring = SpringSpec.spring(duration: 0.45, bounce: 0.1)
    #expect(abs(spring.stiffness - 190) < 8)
    #expect(abs(spring.damping - 24.5) < 1)
  }

  @Test("Раскрытие 175/16 перелетает примерно на 9.5% хода")
  func openOvershoot() {
    let spring = SpringSpec(stiffness: 175, damping: 16)
    #expect(spring.overshoot > 0.085 && spring.overshoot < 0.105)
  }

  @Test("Критическая пружина не перелетает")
  func criticalHasNoOvershoot() {
    #expect(SpringSpec.smooth(duration: 0.4).overshoot == 0)
  }

  @Test("Прогресс идёт от 0 к 1")
  func progressBounds() {
    let spring = SpringSpec(stiffness: 175, damping: 16)
    #expect(abs(spring.progress(at: 0)) < 1e-12)
    #expect(abs(spring.progress(at: 3) - 1) < 1e-4)
  }

  @Test(".smooth(0.4) затухает до 1% примерно за 0.42 с")
  func smoothSettling() {
    let time = SpringSpec.smooth(duration: 0.4).settlingTime()
    #expect(time > 0.39 && time < 0.45)
  }
}
