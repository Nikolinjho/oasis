import AppKit
import IslandCore
import IslandUI
import SwiftUI
import os

/// Ставит окно над вырезом встроенного экрана, переключает клики насквозь и отдаёт hover в store
@MainActor
final class IslandWindowController {
  private let store: IslandStore
  private let menu: NSMenu
  private var panel: NotchPanel?
  private var metrics: NotchMetrics?
  private var monitors: [Any] = []
  private var pointerInside = false
  /// Тело острова, над которым курсор вошёл: держит hover, пока курсор над ним
  private var hoverOpenedFrom: CGRect?
  private var expandedRegion: (view: ExpandedView, body: CGRect)?
  /// Пока контекстное меню острова открыто, курсор на меню и клики в нём не значат «ушёл с острова»
  private var menuOpen = false
  /// Остров закрыт свайпом вверх, а курсор так и стоит над ним: не раскрываем снова, пока курсор не уйдёт
  private var closedBySwipe = false
  /// Левая кнопка мыши зажата
  private var leftButtonDown = false
  /// mouseDown пришёлся на форму острова (панель приняла событие, а не пропустила его сквозь себя):
  /// тянущийся слайдер (прогресс, громкость) не должен схлопнуть остров, если курсор ушёл за его
  /// пределы — реальный hover пересчитывается по отпусканию кнопки (задача 4, репродукция живой проверки)
  private var dragStartedInside = false
  private let log = Logger(subsystem: "dev.nikoko.oasis", category: "window")
  /// Contrast outline: яркость фона под раскрытым
  private lazy var backdrop = BackdropMonitor(store: store)
  /// General → Tuning: смена сразу переставляет остров
  var tuning = NotchTuning() {
    didSet { if tuning != oldValue { placeOnNotchScreen() } }
  }
  /// General → Gestures → Natural movement: источник знака dy у свайпа (swipeInput)
  var naturalMovement = true
  private var composerActive = false
  private lazy var agentInput = ClaudeAgentInputController(store: store)
  private var scrollHandler = IslandScrollHandler()
  var onComposerSurfaceChange: (Surface) -> Void = { _ in }

  init(store: IslandStore, menu: NSMenu) {
    self.store = store
    self.menu = menu
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.placeOnNotchScreen() }
    }
    placeOnNotchScreen()
    installMonitors()
    store.onSurfaceChange = { [weak self] in self?.surfaceChanged() }
    store.onContrastOutlineChange = { [weak self] in self?.backdrop.update(panel: self?.panel) }
    store.onSwipeClose = { [weak self] in self?.closedBySwipe = true }
  }

  private func placeOnNotchScreen() {
    let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }
    guard let screen,
      let measured = NotchMetrics(
        screenFrame: screen.frame,
        auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
        auxiliaryTopRight: screen.auxiliaryTopRightArea,
        safeAreaTop: screen.safeAreaInsets.top)
    else {
      // экрана с вырезом нет (крышка закрыта): прячемся до следующей смены экранов
      panel?.orderOut(nil)
      self.metrics = nil
      pointerInside = false
      hoverOpenedFrom = nil
      return
    }
    let metrics = measured.tuned(by: tuning)
    self.metrics = metrics
    log.info(
      "notch \(metrics.notchSize.width, privacy: .public)x\(metrics.notchSize.height, privacy: .public) (api \(measured.notchSize.width, privacy: .public)x\(measured.notchSize.height, privacy: .public))"
    )
    store.notch = metrics.notchSize
    let frame = IslandGeometry.windowFrame(for: metrics)
    let panel = self.panel ?? makePanel(frame: frame)
    panel.setFrame(frame, display: true)
    if !composerActive { panel.orderFrontRegardless() }
    self.panel = panel
  }

  private func makePanel(frame: CGRect) -> NotchPanel {
    let panel = NotchPanel(frame: frame)
    let hosting = ZeroSafeAreaHostingView(rootView: IslandRootView(store: store))
    hosting.sizingOptions = []
    hosting.frame = CGRect(origin: .zero, size: frame.size)
    hosting.autoresizingMask = [.width, .height]
    panel.contentView = hosting
    return panel
  }

  // swiftlint:disable:next function_body_length - мониторы событий одним списком, порядок установки виден целиком
  private func installMonitors() {
    if let keyboard = NSEvent.addLocalMonitorForEvents(
      matching: .keyDown,
      handler: { [weak self] event in
        guard let self, event.window === panel, agentInput.active, event.keyCode == 53 else { return event }
        store.onAgentsAction(.close)
        return nil
      })
    {
      monitors.append(keyboard)
    }
    let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
    if let global = NSEvent.addGlobalMonitorForEvents(
      matching: moves,
      handler: { [weak self] _ in
        MainActor.assumeIsolated { self?.pointerMoved() }
      })
    {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(
      matching: moves,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.pointerMoved() }
        return event
      })
    {
      monitors.append(local)
    }
    // глобальный монитор видит только клики в чужих окнах: это и есть «клик мимо»
    if let outside = NSEvent.addGlobalMonitorForEvents(
      matching: .leftMouseDown,
      handler: { [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, !self.menuOpen, !self.composerActive else { return }
          self.store.send(.clickedOutside)
        }
      })
    {
      monitors.append(outside)
    }
    // начало и конец жеста мышью: пока кнопка зажата и жест начался над островом, pointerMoved
    // не закрывает его при уходе курсора за пределы формы (задача 4) — только на отпускании
    if let mouseDown = NSEvent.addLocalMonitorForEvents(
      matching: .leftMouseDown,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.leftMouseDown(event) }
        return event
      })
    {
      monitors.append(mouseDown)
    }
    if let mouseUp = NSEvent.addLocalMonitorForEvents(
      matching: .leftMouseUp,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.leftMouseUp() }
        return event
      })
    {
      monitors.append(mouseUp)
    }
    // правый клик по острову открывает меню приложения: иконку в menu bar закрывает компакт
    if let rightClick = NSEvent.addLocalMonitorForEvents(
      matching: .rightMouseDown,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.showMenuIfOnIsland(event) ?? false } ? nil : event
      })
    {
      monitors.append(rightClick)
    }
    // двухпальцевый свайп над островом: окно получает scrollWheel, пока курсор над формой
    if let scroll = NSEvent.addLocalMonitorForEvents(
      matching: .scrollWheel,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.handleScroll(event) ?? false } ? nil : event
      })
    {
      monitors.append(scroll)
    }
  }

  /// Показывает меню у курсора, если правый клик пришёлся на форму острова
  private func showMenuIfOnIsland(_ event: NSEvent) -> Bool {
    guard let panel, event.window === panel else { return false }
    let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
    guard IslandGeometry.reachingScreenTop(island).contains(NSEvent.mouseLocation) else { return false }
    popUpAtPointer(menu)
    return true
  }

  private func handleScroll(_ event: NSEvent) -> Bool {
    guard !composerActive, let panel else { return false }
    return scrollHandler.handle(event, panel: panel, store: store, natural: naturalMovement)
  }

  /// Меню от точки клика, как контекстное меню у Alcove. popUp возвращается, когда меню закрыто:
  /// всё это время hover и клики мимо заморожены, чтобы раскрытый плеер не схлопнулся под меню.
  /// После закрытия сверяемся с курсором: ушёл с острова — схлопнется как обычно
  func popUpAtPointer(_ menu: NSMenu) {
    guard let panel, let content = panel.contentView, !menuOpen else { return }
    let pointer = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
    menuOpen = true
    menu.popUp(positioning: nil, at: content.convert(pointer, from: nil), in: content)
    menuOpen = false
    pointerMoved()
  }

  private func pointerMoved() {
    guard let panel, metrics != nil, !menuOpen, !composerActive else { return }
    // NSTextView может забрать mouseUp в собственном цикле выделения, минуя локальный монитор.
    // Фактическое отпускание снимает удержание острова даже после такого клика.
    if leftButtonDown && NSEvent.pressedMouseButtons & 1 == 0 {
      leftButtonDown = false
      dragStartedInside = false
    }
    let point = NSEvent.mouseLocation
    let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
    // вне формы клики уходят в menu bar и окна под островом
    let local = CGPoint(x: point.x - panel.frame.minX, y: max(0, panel.frame.maxY - point.y))
    panel.ignoresMouseEvents = !PeekQueueGeometry.contains(
      local, content: store.contentSpec, appearance: store.appearance.peekQueue,
      visible: store.showsPeekQueue, windowWidth: panel.frame.width)

    let body = IslandGeometry.bodyScreenRect(store.spec, windowFrame: panel.frame)
    // безопасная зона — только у раскрытого: компакт и hover из покоя держатся по форме, как раньше
    let zone: IslandGeometry.SafeZone? =
      store.model.surface == .expanded ? (store.appearance.progressiveBlur ? .blurred : .plain) : nil
    let inside =
      agentInput.active
      || IslandGeometry.pointerInside(
        point, body: body, island: island, openedFrom: hoverOpenedFrom, expandedSafeZone: zone)
    guard inside != pointerInside else { return }
    guard inside || Self.shouldSendHoverExit(pointerInside: inside, buttonDown: leftButtonDown, dragStartedInside: dragStartedInside)
    else { return }
    pointerInside = inside
    closedBySwipe = Self.keepsClosedBySwipe(closedBySwipe, surface: store.model.surface, pointerInside: inside)
    hoverOpenedFrom = inside ? body : nil
    store.send(inside ? .hoverEntered : .hoverExited)
  }

  /// mouseDown над формой острова: панель приняла событие сама (иначе оно ушло бы сквозь неё, см.
  /// ignoresMouseEvents в pointerMoved), значит жест (клик, начало тяги слайдера) начался над островом
  private func leftMouseDown(_ event: NSEvent) {
    guard event.window === panel else { return }
    leftButtonDown = true
    dragStartedInside = true
  }

  /// Отпускание кнопки: если тяга слайдера всё это время держала остров открытым за пределами формы,
  /// только теперь пересчитываем реальный hover и, если курсор снаружи, закрываем (задача 4)
  private func leftMouseUp() {
    leftButtonDown = false
    dragStartedInside = false
    pointerMoved()
  }

  /// Решает, слать ли hoverExited при уходе курсора с острова. Пока кнопка мыши зажата и жест начался
  /// над островом (тянут прогресс или громкость), уход курсора за пределы формы не должен закрыть
  /// остров и оборвать жест — настоящий hover пересчитывается по отпусканию (задача 4, leftMouseUp)
  static func shouldSendHoverExit(pointerInside: Bool, buttonDown: Bool, dragStartedInside: Bool) -> Bool {
    !pointerInside && !(buttonDown && dragStartedInside)
  }

  /// Смена surface (store.onSurfaceChange): пересчитывает hit-testing и, если курсор всё это время
  /// простоял над островом, а машина как раз вернулась в покой, досылает hoverEntered — иначе
  /// alert/HUD/shrink съедают исходный hoverEntered (машина в этих состояниях его игнорирует),
  /// и остров стоит закрытым, пока курсор не уйдёт и не вернётся
  private func surfaceChanged() {
    retainNavigationRegion()
    agentInput.surfaceChanged(store.model.surface)
    if composerActive {
      if case .hud = store.model.surface { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
      onComposerSurfaceChange(store.model.surface)
      return
    }
    pointerMoved()
    backdrop.update(panel: panel)
    closedBySwipe = Self.keepsClosedBySwipe(closedBySwipe, surface: store.model.surface, pointerInside: pointerInside)
    guard let panel, metrics != nil, !menuOpen,
      Self.shouldReenterHover(surface: store.model.surface, pointerInside: pointerInside, closedBySwipe: closedBySwipe)
    else { return }
    hoverOpenedFrom = IslandGeometry.bodyScreenRect(store.spec, windowFrame: panel.frame)
    store.send(.hoverEntered)
  }

}

extension IslandWindowController {
  private func retainNavigationRegion() {
    if store.model.surface == .expanded, let panel {
      let body = IslandGeometry.bodyScreenRect(store.spec, windowFrame: panel.frame)
      if let previous = expandedRegion, previous.view != store.model.expandedView {
        // После сужения экрана курсор ещё над нажатой кнопкой предыдущего экрана.
        hoverOpenedFrom = previous.body.union(hoverOpenedFrom ?? previous.body)
      }
      expandedRegion = (store.model.expandedView, body)
    } else {
      expandedRegion = nil
    }
  }

  func setAgentInputActive(_ active: Bool) { agentInput.setActive(active, panel: panel) }

  var composerFrame: CGRect {
    panel?.frame ?? CGRect(x: 400, y: 400, width: 624, height: 320)
  }

  func dismissComposer() -> (spec: IslandShapeSpec, animation: Animation) {
    pointerInside = false
    hoverOpenedFrom = nil
    leftButtonDown = false
    dragStartedInside = false
    store.send(.clickedOutside)
    let animation = IslandMotion.spring(for: .collapse, timeScale: store.model.config.timeScale)?.animation ?? .default
    return (store.spec, animation)
  }

  func setComposerActive(_ active: Bool) {
    composerActive = active
    store.setSoonComposing(active)
    if active {
      panel?.orderOut(nil)
    } else {
      panel?.orderFrontRegardless()
      pointerMoved()
    }
  }
}
