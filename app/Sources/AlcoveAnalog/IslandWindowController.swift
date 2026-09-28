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
    /// Пока меню под островом открыто, курсор на меню и клики в нём не значат «ушёл с острова»
    private var menuOpen = false
    /// Остров закрыт свайпом вверх, а курсор так и стоит над ним: не раскрываем снова, пока курсор не уйдёт
    private var closedBySwipe = false
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "window")
    /// General → Tuning: смена сразу переставляет остров
    var tuning = NotchTuning() {
        didSet { if tuning != oldValue { placeOnNotchScreen() } }
    }

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
        store.onSwipeClose = { [weak self] in self?.closedBySwipe = true }
    }

    private func placeOnNotchScreen() {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }
        guard let screen, let measured = NotchMetrics(
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
        log.info("notch \(metrics.notchSize.width, privacy: .public)x\(metrics.notchSize.height, privacy: .public) (api \(measured.notchSize.width, privacy: .public)x\(measured.notchSize.height, privacy: .public))")
        store.notch = metrics.notchSize
        let frame = IslandGeometry.windowFrame(for: metrics)
        let panel = self.panel ?? makePanel(frame: frame)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
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

    private func installMonitors() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return event
        }) { monitors.append(local) }
        // глобальный монитор видит только клики в чужих окнах: это и есть «клик мимо»
        if let outside = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.menuOpen else { return }
                self.store.send(.clickedOutside)
            }
        }) { monitors.append(outside) }
        // правый клик по острову открывает меню приложения: иконку в menu bar закрывает компакт
        if let rightClick = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.showMenuIfOnIsland(event) ?? false } ? nil : event
        }) { monitors.append(rightClick) }
        // двухпальцевый свайп над островом: окно получает scrollWheel, пока курсор над формой
        if let scroll = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleScroll(event) ?? false } ? nil : event
        }) { monitors.append(scroll) }
    }

    /// Показывает меню под островом, если правый клик пришёлся на его форму
    private func showMenuIfOnIsland(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel else { return false }
        let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
        guard IslandGeometry.reachingScreenTop(island).contains(NSEvent.mouseLocation) else { return false }
        popUpUnderIsland(menu)
        return true
    }

    /// Жест трекпада над островом. Не раскрытый — событие не наше: скролл уходит дальше как обычно
    private func handleScroll(_ event: NSEvent) -> Bool {
        guard store.model.surface == .expanded, let panel, event.window === panel,
              let input = Self.swipeInput(
                phase: event.phase, momentumPhase: event.momentumPhase, precise: event.hasPreciseScrollingDeltas,
                deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                inverted: event.isDirectionInvertedFromDevice)
        else { return false }
        store.swipe(input.phase, dx: input.dx, dy: input.dy)
        return true
    }

    /// Разбор события scrollWheel для SwipeTracker. Инерцию не берём: у Alcove её нет. Колесо мыши
    /// (без точных дельт) не трогаем. Натуральная прокрутка: пальцы вниз — dy > 0, как в записи жестов,
    /// без неё знак обратный. Касание (mayBegin) и прочие фазы — nil. Ось (вертикаль или горизонталь) решает трекер
    static func swipeInput(
        phase: NSEvent.Phase, momentumPhase: NSEvent.Phase, precise: Bool,
        deltaX: CGFloat, deltaY: CGFloat, inverted: Bool
    ) -> SwipeInput? {
        guard precise, momentumPhase.isEmpty else { return nil }
        let sign: CGFloat = inverted ? 1 : -1
        let trackerPhase: SwipeTracker.Phase
        switch phase {
        case .began: trackerPhase = .began
        case .changed: trackerPhase = .changed
        case .ended: trackerPhase = .ended
        case .cancelled: trackerPhase = .cancelled
        default: return nil
        }
        guard trackerPhase == .changed else { return SwipeInput(phase: trackerPhase, dx: 0, dy: 0) }
        return SwipeInput(phase: .changed, dx: sign * deltaX, dy: sign * deltaY)
    }

    /// Меню по центру под нижним краем острова. popUp возвращается, когда меню закрыто:
    /// всё это время hover и клики мимо заморожены, чтобы раскрытый плеер не схлопнулся под меню.
    /// После закрытия сверяемся с курсором: ушёл с острова — схлопнется как обычно
    func popUpUnderIsland(_ menu: NSMenu) {
        guard let panel, let content = panel.contentView, !menuOpen else { return }
        let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
        let bottomCentre = panel.convertPoint(fromScreen: CGPoint(x: island.midX, y: island.minY))
        menuOpen = true
        menu.popUp(positioning: nil, at: content.convert(bottomCentre, from: nil), in: content)
        menuOpen = false
        pointerMoved()
    }

    private func pointerMoved() {
        guard let panel, metrics != nil, !menuOpen else { return }
        let point = NSEvent.mouseLocation
        let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
        // вне формы клики уходят в menu bar и окна под островом
        panel.ignoresMouseEvents = !IslandGeometry.reachingScreenTop(island).contains(point)

        let body = IslandGeometry.bodyScreenRect(store.spec, windowFrame: panel.frame)
        let inside = IslandGeometry.pointerInside(point, body: body, island: island, openedFrom: hoverOpenedFrom)
        guard inside != pointerInside else { return }
        pointerInside = inside
        closedBySwipe = Self.keepsClosedBySwipe(closedBySwipe, surface: store.model.surface, pointerInside: inside)
        hoverOpenedFrom = inside ? body : nil
        store.send(inside ? .hoverEntered : .hoverExited)
    }

    /// Смена surface (store.onSurfaceChange): пересчитывает hit-testing и, если курсор всё это время
    /// простоял над островом, а машина как раз вернулась в покой, досылает hoverEntered — иначе
    /// alert/HUD/shrink съедают исходный hoverEntered (машина в этих состояниях его игнорирует),
    /// и остров стоит закрытым, пока курсор не уйдёт и не вернётся
    private func surfaceChanged() {
        pointerMoved()
        closedBySwipe = Self.keepsClosedBySwipe(closedBySwipe, surface: store.model.surface, pointerInside: pointerInside)
        guard let panel, metrics != nil, !menuOpen,
              Self.shouldReenterHover(surface: store.model.surface, pointerInside: pointerInside, closedBySwipe: closedBySwipe)
        else { return }
        hoverOpenedFrom = IslandGeometry.bodyScreenRect(store.spec, windowFrame: panel.frame)
        store.send(.hoverEntered)
    }

    /// Флаг закрытия свайпом держится, пока курсор над островом и остров не раскрыт снова (кликом,
    /// отладкой): иначе он пережил бы новое раскрытие и съел законное переоткрытие после следующего уведомления
    static func keepsClosedBySwipe(_ flag: Bool, surface: Surface, pointerInside: Bool) -> Bool {
        flag && pointerInside && surface != .expanded
    }

    /// true, если сейчас стоит досылать hoverEntered: курсор над островом и surface — состояние покоя
    /// (idle/compact/peek/calendar/calendarPeek). Раскрытые им состояния (hover, hoverNudge, expanded)
    /// в этот список не входят, поэтому повторного hoverEntered из них не будет — зациклиться некому.
    /// После закрытия свайпом вверх (closedBySwipe) не досылаем: иначе курсор у верха острова
    /// раскрывал бы его обратно в тот же момент. Флаг снимается, когда курсор уходит с острова
    static func shouldReenterHover(surface: Surface, pointerInside: Bool, closedBySwipe: Bool = false) -> Bool {
        guard pointerInside, !closedBySwipe else { return false }
        switch surface {
        // компакт календаря тоже покой: иначе после уведомления поверх календаря
        // остров остаётся закрытым под курсором
        case .idle, .compact, .peek, .calendar, .calendarPeek: return true
        default: return false
        }
    }
}

struct IslandRootView: View {
    let store: IslandStore

    var body: some View {
        IslandView(
            model: store.model,
            spec: store.spec,
            notchWidth: store.notch.width,
            nowPlaying: store.nowPlaying,
            agenda: store.agenda,
            calendarEvent: store.calendarEvent,
            dragBlurred: store.dragBlurred,
            appearance: store.appearance,
            onClick: { store.send(.clicked) },
            onAction: { store.onAction($0) },
            onJoin: { store.onJoin($0) })
    }
}
