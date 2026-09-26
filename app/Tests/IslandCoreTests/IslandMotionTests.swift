import Testing
@testable import IslandCore

struct IslandMotionTests {
    static let all: [IslandTransition] = [
        .compactIn, .compactOut, .peekOpen, .peekClose, .hoverOpen, .hoverExpand, .expand,
        .collapse, .hudIn, .hudOut, .hudUpdate, .shrink, .grow,
    ]

    @Test("Схлопывание и сжатие без отскока")
    func collapseAndShrinkAreCritical() throws {
        for transition in [IslandTransition.collapse, .shrink, .hudIn, .hudOut] {
            let spring = try #require(IslandMotion.spring(for: transition))
            #expect(abs(spring.dampingRatio - 1) < 1e-9, "\(transition)")
        }
    }

    @Test("Раскрытие пружинит")
    func expandOvershoots() throws {
        let spring = try #require(IslandMotion.spring(for: .expand))
        #expect(spring.overshoot > 0.05)
    }

    @Test("Hover-раскрытие по замеру видео Alcove, раскрытие кликом по своему замеру")
    func hoverExpandSpring() {
        #expect(IslandMotion.spring(for: .hoverExpand) == SpringSpec(stiffness: 200, damping: 17.5))
        #expect(IslandMotion.spring(for: .expand) == SpringSpec(stiffness: 175, damping: 16))
        #expect(IslandMotion.spring(for: .collapse) == .smooth(duration: 0.4))
    }

    @Test("Новый уровень HUD не анимирует форму")
    func hudUpdateHasNoSpring() {
        #expect(IslandMotion.spring(for: .hudUpdate) == nil)
    }

    @Test("Все пружины затухают быстрее 0.7 с")
    func allSettleQuickly() {
        for transition in Self.all {
            guard let spring = IslandMotion.spring(for: transition) else { continue }
            #expect(spring.settlingTime() < 0.7, "\(transition)")
        }
    }
}
