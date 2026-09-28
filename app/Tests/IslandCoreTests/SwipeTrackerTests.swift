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
}
