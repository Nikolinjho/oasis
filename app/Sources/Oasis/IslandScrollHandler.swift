import AppKit
import IslandCore
import SwiftUI

/// Разделяет горизонтальную навигацию, вертикальные жесты острова и прокрутку списков.
@MainActor
struct IslandScrollHandler {
  private var scrollInList = false
  private var backTracker = SwipeTracker()

  mutating func handle(_ event: NSEvent, panel: NotchPanel, store: IslandStore, natural: Bool) -> Bool {
    guard event.window === panel,
      let input = IslandWindowController.swipeInput(
        phase: event.phase, momentumPhase: event.momentumPhase, precise: event.hasPreciseScrollingDeltas,
        deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
        inverted: event.isDirectionInvertedFromDevice, natural: natural)
    else { return false }
    if input.phase == .began {
      scrollInList = pointerOverList(panel: panel, store: store)
      store.backSwipe.reset()
      backTracker = SwipeTracker(
        tracksBack: store.model.surface == .expanded
          && (store.config.dashboardNavigation || store.model.expandedView.isAgents || store.model.expandedView == .inbox))
    }
    // Возврат следует за пальцами, независимо от Natural movement и системной настройки прокрутки.
    let direction: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
    if handleBackSwipe(input, dx: direction * event.scrollingDeltaX, store: store) {
      if input.phase == .ended || input.phase == .cancelled {
        scrollInList = false
        store.swipe(input.phase, dx: input.dx, dy: input.dy)
      }
      return true
    }
    if scrollInList {
      if input.phase == .ended || input.phase == .cancelled { scrollInList = false }
      return false
    }
    let surface = store.model.surface
    let ours = surface == .expanded || (store.swipeToDismiss && IslandStore.isRestSwipeSurface(surface))
    guard ours else {
      if input.phase != .changed { store.swipe(input.phase, dx: input.dx, dy: input.dy) }
      return false
    }
    store.swipe(input.phase, dx: input.dx, dy: input.dy)
    return true
  }

  private mutating func handleBackSwipe(_ input: SwipeInput, dx: CGFloat, store: IslandStore) -> Bool {
    let wasHorizontal = backTracker.isHorizontal
    let output = backTracker.feed(input.phase, dx: dx, dy: input.dy)
    guard store.model.surface == .expanded, wasHorizontal || backTracker.isHorizontal else { return false }
    let timeScale = store.config.timeScale
    if output == .back {
      withAnimation(.smooth(duration: 0.25 * timeScale)) {
        store.backSwipe.navigating = store.navigateBack()
        store.backSwipe.settle(timeScale: timeScale)
      }
      if store.backSwipe.navigating {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
      }
    } else if input.phase == .changed, store.model.expandedView.backTarget != nil {
      store.backSwipe.drag(progress: backTracker.backProgress)
    }
    if input.phase == .ended || input.phase == .cancelled { store.backSwipe.settle(timeScale: timeScale) }
    return true
  }

  /// Владелец прокрутки определяется один раз: перемещение курсора не обрывает уже начатый свайп.
  private func pointerOverList(panel: NotchPanel, store: IslandStore) -> Bool {
    guard store.model.surface == .expanded else { return false }
    let pointer = NSEvent.mouseLocation
    if store.model.expandedView.isAgents || store.model.expandedView == .inbox { return true }
    if store.model.expandedView == .soon {
      let header: CGFloat = store.config.dashboardNavigation ? ExpandedLayout.headerHeight : 0
      return pointer.y < panel.frame.maxY - 54 - header
    }
    guard store.model.expandedView == .overview, store.soonPanel != nil else { return false }
    let body = IslandGeometry.bodyScreenRect(store.spec, windowFrame: panel.frame)
    return pointer.x >= body.maxX - 230 && pointer.x <= body.maxX - 24
      && pointer.y < panel.frame.maxY - 62 && pointer.y > panel.frame.maxY - 174
  }

}
