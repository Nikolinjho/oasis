import CoreGraphics
import IslandCore
import Testing
@testable import AlcoveAnalog

@MainActor
struct IslandStoreSwipeTests {
    /// Store с раскрытым островом: hover в режиме пользователя раскрывает сразу
    static func expanded() -> IslandStore {
        let store = IslandStore(config: .user)
        store.send(.hoverEntered)
        return store
    }

    static func delta(_ travel: CGFloat) -> CGFloat { travel / SwipeTracker.pointsPerDelta }

    @Test("Свайп вниз тянет форму и на отпускании листает вид, тяга сбрасывается")
    func downCyclesView() {
        let store = Self.expanded()
        #expect(store.model.surface == .expanded)
        let rest = store.spec.size.height
        store.swipe(.began, dy: 0)
        store.swipe(.changed, dy: Self.delta(20))
        #expect(store.stretch > 0)
        #expect(store.spec.size.height == rest + store.stretch)
        #expect(!store.dragBlurred)
        store.swipe(.ended, dy: 0)
        #expect(store.model.expandedView == .player)
        #expect(store.stretch == 0)
        #expect(store.spec.size.height == rest)
    }

    @Test("Свайп вверх до порога — блюр и сжатие, отпускание возвращает без смены вида")
    func upSettles() {
        let store = Self.expanded()
        store.swipe(.began, dy: 0)
        store.swipe(.changed, dy: Self.delta(-10))
        #expect(store.stretch == -10)
        #expect(store.dragBlurred)
        store.swipe(.ended, dy: 0)
        #expect(store.stretch == 0)
        #expect(!store.dragBlurred)
        #expect(store.model.surface == .expanded)
        #expect(store.model.expandedView == .duo)
    }

    @Test("Порог вверх схлопывает остров сразу, отпускание после этого ничего не делает")
    func upCloses() {
        let store = Self.expanded()
        var closes = 0
        store.onSwipeClose = { closes += 1 }
        store.swipe(.began, dy: 0)
        store.swipe(.changed, dy: Self.delta(-25))
        #expect(store.model.surface != .expanded)
        #expect(store.stretch == 0)
        #expect(!store.dragBlurred)
        store.swipe(.changed, dy: Self.delta(-10))
        store.swipe(.ended, dy: 0)
        #expect(closes == 1)
        #expect(store.stretch == 0)
    }

    @Test("Остров ушёл из раскрытого посреди жеста — тяга и блюр не переживают следующее раскрытие")
    func stretchResetsWhenLeavingExpanded() {
        let store = Self.expanded()
        store.swipe(.began, dy: 0)
        store.swipe(.changed, dy: Self.delta(-10))
        #expect(store.dragBlurred)
        store.send(.clickedOutside)
        #expect(store.stretch == 0)
        #expect(!store.dragBlurred)
        store.send(.hoverEntered)
        #expect(store.model.surface == .expanded)
        #expect(store.spec.size.height == IslandGeometry.expanded.height)
    }

    @Test("Вне раскрытого свайп ничего не делает")
    func ignoredWhenNotExpanded() {
        let store = IslandStore(config: .user)
        store.swipe(.began, dy: 0)
        store.swipe(.changed, dy: Self.delta(20))
        store.swipe(.ended, dy: 0)
        #expect(store.stretch == 0)
        #expect(store.model.surface != .expanded)
    }
}
