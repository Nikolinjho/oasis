import AppKit
import IslandCore
import IslandUI
import SwiftUI

/// Ставит окно над вырезом встроенного экрана, переключает клики насквозь и отдаёт hover в store
@MainActor
final class IslandWindowController {
    private let store: IslandStore
    private var panel: NotchPanel?
    private var metrics: NotchMetrics?
    private var monitors: [Any] = []
    private var pointerInside = false
    /// Форма (с зоной hover в покое), над которой курсор вошёл: держит hover, пока курсор над ней
    private var hoverOpenedFrom: CGRect?

    init(store: IslandStore) {
        self.store = store
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeOnNotchScreen() }
        }
        placeOnNotchScreen()
        installMonitors()
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
            MainActor.assumeIsolated { self?.store.send(.clickedOutside) }
        }) { monitors.append(outside) }
    }

    private func pointerMoved() {
        guard let panel, let metrics else { return }
        let point = NSEvent.mouseLocation
        let island = IslandGeometry.islandScreenRect(store.spec, windowFrame: panel.frame)
        // вне формы клики уходят в menu bar и окна под островом
        panel.ignoresMouseEvents = !island.contains(point)

        let zone = store.model.surface == .idle ? IslandGeometry.hoverZone(for: metrics) : nil
        let inside = IslandGeometry.pointerInside(point, island: island, hoverZone: zone, openedFrom: hoverOpenedFrom)
        guard inside != pointerInside else { return }
        pointerInside = inside
        hoverOpenedFrom = inside ? zone.map(island.union) ?? island : nil
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
            onCommand: { store.onCommand($0) })
    }
}
