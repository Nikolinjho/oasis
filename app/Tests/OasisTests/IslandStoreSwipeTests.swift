import CoreGraphics
import IslandCore
import Testing

@testable import Oasis

@MainActor
struct IslandStoreSwipeTests {
  /// Store с раскрытым островом: hover в режиме пользователя раскрывает сразу
  static func expanded() -> IslandStore {
    let store = IslandStore(config: .user)
    store.send(.hoverEntered)
    return store
  }

  static func delta(_ travel: CGFloat) -> CGFloat { travel / SwipeTracker.pointsPerDelta }

  /// Store с компактом музыки под курсором: Expand on hover выключен, hover даёт только отклик
  static func compactStore() -> IslandStore {
    let store = IslandStore(config: IslandMachine.Config.user.applying(expandOnHover: false, hoverDuration: 0))
    store.apply(.newTrack(NowPlayingInfo(title: "T", isPlaying: true)))
    return store
  }

  @Test("Свайп вниз тянет форму и на пороге 21 pt сразу листает вид, тяга сбрасывается, отпускание ничего не делает")
  func downCyclesView() {
    let store = Self.expanded()
    #expect(store.model.surface == .expanded)
    let rest = store.spec.size.height
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(15))
    #expect(store.stretch > 0)
    #expect(store.spec.size.height == rest + store.stretch)
    #expect(!store.dragBlurred)
    #expect(store.model.expandedView == .duo)
    store.swipe(.changed, dy: Self.delta(10))
    #expect(store.model.expandedView == .player)
    #expect(store.stretch == 0)
    #expect(store.spec.size.height == rest)
    store.swipe(.changed, dy: Self.delta(30))
    store.swipe(.ended, dy: 0)
    #expect(store.model.expandedView == .player)
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

  @Test("Жест, отменённый системой после движения вниз, возвращает высоту и не листает")
  func cancelledDoesNotCycle() {
    let store = Self.expanded()
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(20))
    store.swipe(.cancelled, dy: 0)
    #expect(store.model.expandedView == .duo)
    #expect(store.stretch == 0)
  }

  @Test("Горизонтальный свайп по раскрытому ничего не делает")
  func horizontalIgnored() {
    let store = Self.expanded()
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dx: 40, dy: 5)
    store.swipe(.ended, dy: 0)
    #expect(store.model.expandedView == .duo)
    #expect(store.stretch == 0)
    #expect(store.model.surface == .expanded)
  }

  @Test("Свайп вверх по компакту на 21 pt убирает активность и держит остров закрытым под курсором")
  func compactDismiss() {
    let store = Self.compactStore()
    var closed = false
    store.onSwipeClose = { closed = true }
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(store.model.dismissed)
    #expect(closed)
    store.swipe(.ended, dy: 0)
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(22))
    #expect(!store.model.dismissed)
  }

  @Test("Swipe to dismiss activity выключен: свайп по компакту ничего не делает")
  func compactDismissOff() {
    let store = Self.compactStore()
    store.swipeToDismiss = false
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(!store.model.dismissed)
  }

  @Test("Долгий свайп вверх по раскрытому: после close остаток того же жеста не убирает вернувшийся компакт")
  func upCloseContinuationIgnoresRestSwipe() {
    let store = Self.expanded()
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(store.model.surface != .expanded)
    // тот же жест, без нового .began: раскрытый трекер уже сработал и держит fired,
    // второй проход тех же пальцев не должен достаться restTracker вернувшегося компакта/выреза
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(!store.model.dismissed)
    store.swipe(.ended, dy: 0)
    #expect(!store.model.dismissed)
  }

  @Test("Свайп вверх, когда убирать нечего, не даёт отклика: остров не держится закрытым под курсором")
  func dismissNoOpDoesNotClose() {
    let store = IslandStore(config: .user)
    var closed = false
    store.onSwipeClose = { closed = true }
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(!store.model.dismissed)
    #expect(!closed)
  }

  @Test("Свайп вниз, когда убирать нечего, не даёт отклика: активность и так не убрана")
  func restoreNoOpKeepsDismissedFalse() {
    let store = Self.compactStore()
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(22))
    #expect(!store.model.dismissed)
  }

  @Test("Swipe to dismiss activity выключили, пока активность убрана: без тумблера её больше нечем вернуть, поэтому она возвращается сама")
  func disablingSwipeToDismissRestoresDismissed() {
    let (name, defaults) = AppSettingsTests.freshDefaults()
    defer { AppSettingsTests.cleanup(name, defaults) }
    let store = Self.compactStore()
    let settings = AppSettings(defaults: defaults)
    // тот же кусок, что в AppDelegate.applySettings
    settings.onChange = {
      if store.swipeToDismiss, !settings.swipeToDismiss { store.send(.activityRestored) }
      store.swipeToDismiss = settings.swipeToDismiss
    }
    store.swipeToDismiss = settings.swipeToDismiss
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(store.model.dismissed)

    settings.swipeToDismiss = false
    #expect(!store.model.dismissed)
  }

  @Test("onSwipeClose срабатывает раньше onSurfaceChange: окно успевает выставить closedBySwipe до синхронного hoverEntered")
  func closeFiresBeforeSurfaceChange() {
    let store = Self.compactStore()
    var closedBeforeSurfaceChange = false
    var surfaceChangedCalls = 0
    store.onSwipeClose = { closedBeforeSurfaceChange = true }
    store.onSurfaceChange = {
      surfaceChangedCalls += 1
      // send зовёт onSurfaceChange синхронно: к этому моменту onSwipeClose уже должен был отработать,
      // иначе окно успело бы послать hoverEntered раньше и отменить dismiss тем же кадром (review Task 15)
      #expect(closedBeforeSurfaceChange)
    }
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(store.model.dismissed)
    #expect(surfaceChangedCalls == 1)
    #expect(closedBeforeSurfaceChange)
  }

  @Test("Новый .began пересчитывает владельца жеста и трекеры заново, даже если у предыдущего жеста не было .ended")
  func beganAlwaysResetsOwnerAndTrackers() {
    let store = Self.compactStore()
    // первый жест недотянут до порога и не получил .ended (например, handleScroll не переслал его,
    // потому что HUD увёл surface из наших посреди жеста)
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(5))
    #expect(!store.model.dismissed)

    // новый жест — свежий .began обязан заново решить владельца и трекеры, а не унаследовать состояние
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-22))
    #expect(store.model.dismissed)
  }

  @Test("Surface ушла из раскрытого не через сам жест (HUD посреди свайпа): тяга не зависает и не искажает следующее раскрытие")
  func expandedLeftMidGestureByOtherEventResetsStretch() {
    let store = Self.expanded()
    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(-10))
    #expect(store.stretch == -10)
    #expect(store.dragBlurred)

    // HUD пришёл не через свайп: surface уходит из .expanded независимо от жеста
    store.send(.hudChanged(.volume, level: 0.5))
    #expect(store.model.surface != .expanded)
    #expect(store.stretch == 0)

    // тот же физический жест продолжается: раскрытый трекер ещё не .fired и без фикса вернул бы новый .stretch
    store.swipe(.changed, dy: Self.delta(-5))
    #expect(store.stretch == 0)
    #expect(!store.dragBlurred)

    store.swipe(.ended, dy: 0)
    #expect(store.stretch == 0)
  }

  @Test("Радиус на старте тяги плеера со строкой громкости считается без её высоты (review финала P2, п.2)")
  func volumeRowStretchRadiusIgnoresRowHeight() {
    let store = Self.expanded()
    store.send(.expandedViewCycled)  // duo → player: строка громкости живёт только в нём
    #expect(store.model.expandedView == .player)
    store.send(.volumeRowToggled)
    #expect(store.model.volumeRowShown)
    // в покое (stretch == 0) геометрия сама уже держит радиус по высоте без строки громкости (175, не 207) —
    // сверяем это как опору перед тягой
    #expect(store.spec.size.height == 207)
    #expect(abs(store.spec.bottomRadius - IslandGeometry.bottomRadius(forHeight: 175)) < 1e-9)

    store.swipe(.began, dy: 0)
    store.swipe(.changed, dy: Self.delta(10))
    #expect(store.stretch > 0)
    #expect(store.spec.size.height == 207 + store.stretch)
    // без фикса радиус считался бы от полной высоты (207 + stretch), а не от 175 + stretch,
    // как в покое — угол скакнул бы на старте свайпа
    #expect(abs(store.spec.bottomRadius - IslandGeometry.bottomRadius(forHeight: 175 + store.stretch)) < 1e-9)
    #expect(abs(store.spec.bottomRadius - IslandGeometry.bottomRadius(forHeight: 207 + store.stretch)) > 0.5)
  }
}
