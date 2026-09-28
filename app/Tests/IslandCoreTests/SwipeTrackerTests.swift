import CoreGraphics
import Testing
@testable import IslandCore

struct SwipeTrackerTests {
    /// Дельта скролла, которая даёт travel pt
    static func delta(_ travel: CGFloat) -> CGFloat { travel / SwipeTracker.pointsPerDelta }

    @Test("Вниз — растяжение с потолком 7 pt, отпускание листает вид")
    func downCycles() {
        var tracker = SwipeTracker()
        #expect(tracker.feed(.began, dy: 0) == nil)
        guard case let .stretch(small)? = tracker.feed(.changed, dy: Self.delta(5)) else { Issue.record("нет растяжения"); return }
        #expect(small > 0 && small < 5)
        guard case let .stretch(big)? = tracker.feed(.changed, dy: Self.delta(200)) else { Issue.record("нет растяжения"); return }
        #expect(big <= SwipeTracker.stretchCeiling)
        #expect(big > 6.9)
        #expect(tracker.feed(.ended, dy: 0) == .cycle)
    }

    @Test("Вверх — за пальцами без сопротивления, отпускание до порога возвращает")
    func upSettles() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        #expect(tracker.feed(.changed, dy: Self.delta(-10)) == .stretch(-10))
        #expect(tracker.feed(.ended, dy: 0) == .settle)
    }

    @Test("Порог 21 pt вверх закрывает сразу и один раз, остаток жеста игнорируется")
    func upCloses() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        _ = tracker.feed(.changed, dy: Self.delta(-15))
        #expect(tracker.feed(.changed, dy: Self.delta(-7)) == .close)
        #expect(tracker.feed(.changed, dy: Self.delta(-20)) == nil)
        #expect(tracker.feed(.ended, dy: 0) == nil)
    }

    @Test("Короткое касание без движения вниз не листает")
    func tinyDownSettles() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        _ = tracker.feed(.changed, dy: Self.delta(0.5))
        #expect(tracker.feed(.ended, dy: 0) == .settle)
    }

    @Test("Отмена жеста системой возвращает, но не листает, даже после движения вниз")
    func cancelledSettles() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        _ = tracker.feed(.changed, dy: Self.delta(10))
        #expect(tracker.feed(.cancelled, dy: 0) == .settle)
    }

    @Test("Отмена после закрытия порогом ничего не делает")
    func cancelledAfterCloseIgnored() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        #expect(tracker.feed(.changed, dy: Self.delta(-25)) == .close)
        #expect(tracker.feed(.cancelled, dy: 0) == nil)
    }

    @Test("Горизонтальный жест: ось фиксируется в начале, весь жест игнорируется, даже если потом пошёл вниз")
    func horizontalIgnored() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        #expect(tracker.feed(.changed, dx: 6, dy: 1) == nil)
        #expect(tracker.feed(.changed, dx: 1, dy: Self.delta(-30)) == nil)
        #expect(tracker.feed(.ended, dy: 0) == nil)
        // следующий жест снова свой: ось решается заново
        _ = tracker.feed(.began, dy: 0)
        #expect(tracker.feed(.changed, dy: Self.delta(-10)) == .stretch(-10))
    }

    @Test("Вертикальный жест с дрожью по горизонтали не теряет событий")
    func verticalWithJitter() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        // как в scroll-1.log: dy=3 dx=1, dy=1 dx=1
        _ = tracker.feed(.changed, dx: 1, dy: 3)
        _ = tracker.feed(.changed, dx: 1, dy: 1)
        // решение по оси принято, дальше события с dx > dy не отбрасываются
        #expect(tracker.feed(.changed, dx: 3, dy: 2) != nil)
        #expect(tracker.feed(.ended, dy: 0) == .cycle)
    }

    @Test("Пока ось не решена, растяжения нет: мелкие первые события копятся")
    func axisPendingNoOutput() {
        var tracker = SwipeTracker()
        _ = tracker.feed(.began, dy: 0)
        #expect(tracker.feed(.changed, dx: 0, dy: 1) == nil)
        guard case .stretch? = tracker.feed(.changed, dx: 0, dy: 4) else { Issue.record("нет растяжения"); return }
    }
}
