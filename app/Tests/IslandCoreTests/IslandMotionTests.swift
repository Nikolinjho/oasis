import Testing
@testable import IslandCore

struct IslandMotionTests {
    static let all: [IslandTransition] = [
        .compactIn, .compactOut, .peekOpen, .peekClose, .hoverOpen, .hoverExpand, .expand,
        .collapse, .hudIn, .hudOut, .hudUpdate, .shrink, .grow, .hoverNudge, .hoverNudgeBack,
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

    @Test("Отклик на hover и возврат из него — мягкая пружина без отскока, короче таймера раскрытия")
    func hoverNudgeSpring() throws {
        for transition in [IslandTransition.hoverNudge, .hoverNudgeBack] {
            let spring = try #require(IslandMotion.spring(for: transition))
            #expect(spring == .smooth(duration: 0.13), "\(transition)")
        }
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

struct TimeScaleTests {
    @Test("Замедление сохраняет ζ и растягивает затухание ровно в 1.18 раза")
    func slowedKeepsCharacter() throws {
        for transition in IslandMotionTests.all {
            guard let spring = IslandMotion.spring(for: transition) else { continue }
            let slow = try #require(IslandMotion.spring(for: transition, timeScale: 1.18))
            #expect(abs(slow.dampingRatio - spring.dampingRatio) < 1e-9, "\(transition)")
            #expect(abs(slow.settlingTime() - spring.settlingTime() * 1.18) < 0.005, "\(transition)")
        }
    }

    @Test("Hover 200/17.5 при 1.18 — примерно 143.6/14.8, smooth(0.4) — smooth(0.472)")
    func slowedNumbers() throws {
        let hover = try #require(IslandMotion.spring(for: .hoverExpand, timeScale: 1.18))
        #expect(abs(hover.stiffness - 143.63) < 0.01 && abs(hover.damping - 14.83) < 0.01)
        let collapse = try #require(IslandMotion.spring(for: .collapse, timeScale: 1.18))
        let smooth = SpringSpec.smooth(duration: 0.4 * 1.18)
        #expect(abs(collapse.stiffness - smooth.stiffness) < 1e-9 && abs(collapse.damping - smooth.damping) < 1e-9)
    }

    @Test("Режим Alcove не замедляется, пользовательский — в 1.18 раза")
    func configScales() {
        #expect(IslandMachine.Config.alcove.timeScale == 1)
        #expect(IslandMachine.Config.user.timeScale == 1.18)
    }

    @Test("Таймеры сжатия и схлопывания растягиваются вместе с пружинами")
    func timersFollowScale() {
        var m = IslandModel()
        m.surface = .compact
        m.hasMedia = true
        let shrink = IslandMachine.reduce(&m, .hudChanged(.volume, level: 0.5))
        #expect(shrink == [.cancel(.peekEnd), .animate(.shrink), .schedule(.grow, after: IslandTiming.shrink * 1.18)])

        var open = IslandModel()
        open.surface = .expanded
        let collapse = IslandMachine.reduce(&open, .hudChanged(.volume, level: 0.5))
        #expect(collapse == [.animate(.collapse), .schedule(.collapseDone, after: IslandTiming.collapse * 1.18)])
    }
}
