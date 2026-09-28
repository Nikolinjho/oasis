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
struct IslandWindowControllerSwipeCloseTests {
    @Test("После закрытия свайпом hoverEntered не досылаем, пока курсор не ушёл с острова")
    func noReentryAfterSwipeClose() {
        #expect(!IslandWindowController.shouldReenterHover(surface: .idle, pointerInside: true, closedBySwipe: true))
        #expect(!IslandWindowController.shouldReenterHover(surface: .compact, pointerInside: true, closedBySwipe: true))
        #expect(IslandWindowController.shouldReenterHover(surface: .compact, pointerInside: true, closedBySwipe: false))
    }
}
