import AppKit
import IslandCore
import Testing
@testable import AlcoveAnalog

@MainActor
struct IslandWindowControllerTests {
    @Test("Курсор ушёл — hoverEntered досылать некуда, независимо от surface")
    func pointerOutside() {
        #expect(!IslandWindowController.shouldReenterHover(surface: .idle, pointerInside: false))
        #expect(!IslandWindowController.shouldReenterHover(surface: .compact, pointerInside: false))
        #expect(!IslandWindowController.shouldReenterHover(surface: .alert(.charging(level: 0.5)), pointerInside: false))
    }

    @Test("Курсор на острове и surface вернулась в покой — hoverEntered досылаем")
    func reentersFromRestStates() {
        #expect(IslandWindowController.shouldReenterHover(surface: .idle, pointerInside: true))
        #expect(IslandWindowController.shouldReenterHover(surface: .compact, pointerInside: true))
        #expect(IslandWindowController.shouldReenterHover(surface: .peek, pointerInside: true))
        #expect(IslandWindowController.shouldReenterHover(surface: .calendar, pointerInside: true))
        #expect(IslandWindowController.shouldReenterHover(surface: .calendarPeek, pointerInside: true))
    }

    @Test("Курсор на острове, но surface не покой (alert/HUD/shrink) — не наше дело, машина сама разберётся")
    func noReentryFromActiveStates() {
        #expect(!IslandWindowController.shouldReenterHover(surface: .alert(.charging(level: 1)), pointerInside: true))
        #expect(!IslandWindowController.shouldReenterHover(surface: .hud(.volume, level: 0.5), pointerInside: true))
        #expect(!IslandWindowController.shouldReenterHover(surface: .shrink, pointerInside: true))
    }

    @Test("Уже раскрытое hoverEntered не досылаем: цикл не запускаем")
    func noLoopFromAlreadyOpenStates() {
        #expect(!IslandWindowController.shouldReenterHover(surface: .hover, pointerInside: true))
        #expect(!IslandWindowController.shouldReenterHover(surface: .hoverNudge(from: .compact), pointerInside: true))
        #expect(!IslandWindowController.shouldReenterHover(surface: .expanded, pointerInside: true))
    }
}

@MainActor
struct IslandWindowControllerDragTests {
    typealias W = IslandWindowController

    @Test("Курсор внутри — hoverExited не нужен независимо от кнопки и старта жеста")
    func insideNeverExits() {
        #expect(!W.shouldSendHoverExit(pointerInside: true, buttonDown: false, dragStartedInside: false))
        #expect(!W.shouldSendHoverExit(pointerInside: true, buttonDown: true, dragStartedInside: true))
    }

    @Test("Курсор снаружи, кнопка отпущена — обычный уход, hoverExited шлём")
    func outsideWithoutButtonExits() {
        #expect(W.shouldSendHoverExit(pointerInside: false, buttonDown: false, dragStartedInside: false))
        // кнопка зажата, но жест начался не над островом — тянут что-то другое, это не наш случай
        #expect(W.shouldSendHoverExit(pointerInside: false, buttonDown: true, dragStartedInside: false))
    }

    @Test("Тянут слайдер (кнопка зажата, жест начался над островом) — курсор снаружи не закрывает остров")
    func draggingFromIslandSuppressesExit() {
        #expect(!W.shouldSendHoverExit(pointerInside: false, buttonDown: true, dragStartedInside: true))
    }
}

@MainActor
struct IslandWindowControllerSwipeCloseTests {
    @Test("После закрытия свайпом hoverEntered не досылаем, пока курсор не ушёл с острова")
    func noReentryAfterSwipeClose() {
        #expect(!IslandWindowController.shouldReenterHover(surface: .idle, pointerInside: true, closedBySwipe: true))
        #expect(!IslandWindowController.shouldReenterHover(surface: .compact, pointerInside: true, closedBySwipe: true))
        #expect(IslandWindowController.shouldReenterHover(surface: .compact, pointerInside: true, closedBySwipe: false))
    }

    @Test("Флаг закрытия свайпом снимается, когда остров снова раскрыт или курсор ушёл")
    func swipeCloseFlagClears() {
        #expect(IslandWindowController.keepsClosedBySwipe(true, surface: .idle, pointerInside: true))
        #expect(!IslandWindowController.keepsClosedBySwipe(true, surface: .expanded, pointerInside: true))
        #expect(!IslandWindowController.keepsClosedBySwipe(true, surface: .idle, pointerInside: false))
        #expect(!IslandWindowController.keepsClosedBySwipe(false, surface: .idle, pointerInside: true))
    }
}

@MainActor
struct IslandWindowControllerSwipeInputTests {
    typealias W = IslandWindowController

    static func input(
        _ phase: NSEvent.Phase, momentum: NSEvent.Phase = [], precise: Bool = true,
        dx: CGFloat = 0, dy: CGFloat = 0, inverted: Bool = true
    ) -> SwipeInput? {
        W.swipeInput(phase: phase, momentumPhase: momentum, precise: precise, deltaX: dx, deltaY: dy, inverted: inverted)
    }

    @Test("Фазы трекпада переходят в фазы трекера, касание и прочие — нет")
    func phases() {
        #expect(Self.input(.began)?.phase == .began)
        #expect(Self.input(.changed, dy: 2)?.phase == .changed)
        #expect(Self.input(.ended)?.phase == .ended)
        #expect(Self.input(.cancelled)?.phase == .cancelled)
        #expect(Self.input(.mayBegin) == nil)
        #expect(Self.input(.stationary) == nil)
        #expect(Self.input([]) == nil)
    }

    @Test("Инерция и колесо мыши без точных дельт отбрасываются")
    func dropped() {
        #expect(Self.input([], momentum: .changed, dy: 5) == nil)
        #expect(Self.input(.changed, momentum: .began, dy: 5) == nil)
        #expect(Self.input(.changed, precise: false, dy: 5) == nil)
    }

    @Test("Знак: при натуральной прокрутке дельта как есть, без неё обратная. Пальцы вниз — dy > 0")
    func sign() {
        #expect(Self.input(.changed, dx: 1, dy: 3, inverted: true) == SwipeInput(phase: .changed, dx: 1, dy: 3))
        #expect(Self.input(.changed, dx: 1, dy: 3, inverted: false) == SwipeInput(phase: .changed, dx: -1, dy: -3))
    }

    @Test("Горизонтальная дельта доходит до трекера: ось решает он")
    func horizontalPassesThrough() {
        #expect(Self.input(.changed, dx: 7, dy: 0) == SwipeInput(phase: .changed, dx: 7, dy: 0))
    }

    @Test("Natural movement выкл: жест как прокрутка контента, знак от системной натуральной прокрутки")
    func naturalMovement() {
        let natural = IslandWindowController.swipeInput(
            phase: .changed, momentumPhase: [], precise: true, deltaX: 0, deltaY: 5, inverted: true, natural: true)
        let content = IslandWindowController.swipeInput(
            phase: .changed, momentumPhase: [], precise: true, deltaX: 0, deltaY: 5, inverted: true, natural: false)
        #expect(natural?.dy == 5)
        #expect(content?.dy == -5)
        let plain = IslandWindowController.swipeInput(
            phase: .changed, momentumPhase: [], precise: true, deltaX: 0, deltaY: 5, inverted: false, natural: false)
        #expect(plain?.dy == -5)
    }
}
