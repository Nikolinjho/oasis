import AppKit
import IslandCore
import IslandUI
import SwiftUI

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
        store.onSurfaceChange = { [weak self] in self?.pointerMoved() }
    }

    private func placeOnNotchScreen() {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }
        guard let screen, let metrics = NotchMetrics(
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
        self.metrics = metrics
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
    }

    /// Показывает меню под островом, если правый клик пришёлся на его форму
    private func showMenuIfOnIsland(_ event: NSEvent) -> Bool {
        guard let panel, event.window === panel else { return false }
        let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
        guard IslandGeometry.reachingScreenTop(island).contains(NSEvent.mouseLocation) else { return false }
        popUpUnderIsland(menu)
        return true
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
        hoverOpenedFrom = inside ? body : nil
        store.send(inside ? .hoverEntered : .hoverExited)
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
            onClick: { store.send(.clicked) },
            onAction: { store.onAction($0) })
    }
}
