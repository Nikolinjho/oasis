import AppKit
import IslandCore
import IslandSources
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private var window: IslandWindowController?
    private var statusItem: StatusItemController?
    private var nowPlaying: AdapterNowPlayingSource?
    private var volume: VolumeControl?
    private var brightness: BrightnessControl?
    private var keyTap: MediaKeyTap?
    private var trustTimer: Timer?
    private var fullscreen: FullscreenMonitor?
    private var tasks: [Task<Void, Never>] = []
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // статус-айтем раньше окна: остров открывает его меню по правому клику
        let statusItem = StatusItemController(
            debugItems: DebugMenu.items(store: store),
            isTrusted: { Permissions.isAccessibilityTrusted })
        self.statusItem = statusItem
        window = IslandWindowController(store: store, menu: statusItem.menu)
        startFullscreenMonitor()
        startNowPlaying()
        startPlayerActions()
        startLevels()
        startKeyTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.stop()
    }

    /// Полноэкранное приложение на экране с вырезом прячет компакт музыки
    private func startFullscreenMonitor() {
        let monitor = FullscreenMonitor { [store, log] isFullscreen in
            log.info("fullscreen \(isFullscreen ? "on" : "off")")
            store.send(.fullscreenChanged(isFullscreen))
        }
        monitor.start()
        fullscreen = monitor
    }

    private func startNowPlaying() {
        // kill -9 и падение не дают выйти штатно: сироты прошлых запусков гасим здесь
        let stale = StaleAdapters.terminate()
        if stale > 0 { log.info("terminated \(stale) stale adapter(s)") }
        guard let paths = AdapterPaths.locate() else {
            log.error("mediaremote-adapter not found in bundle resources")
            return
        }
        let source = AdapterNowPlayingSource(paths: paths)
        tasks.append(Task { [store] in
            for await change in source.changes { store.apply(change) }
        })
        source.start()
        nowPlaying = source
    }

    /// Кнопки плеера. Без адаптера медиакоманды пропадают, остальные кнопки работают
    private func startPlayerActions() {
        let performer = PlayerActions(source: nowPlaying) { [weak window] menu in window?.popUpUnderIsland(menu) }
        let router = PlayerActionRouter(performer: performer)
        store.onAction = { [weak store, log] action in
            guard let store else { return }
            log.debug("player action \(String(describing: action), privacy: .public)")
            router.perform(action, nowPlaying: store.nowPlaying)
        }
    }

    private func startLevels() {
        // HUD громкости всегда идёт от слушателя CoreAudio: и в режиме перехвата, и без Accessibility
        let volume = VolumeControl()
        tasks.append(Task { [store] in
            for await level in volume.changes { store.send(.hudChanged(.volume, level: level)) }
        })
        self.volume = volume
        brightness = BrightnessControl()
        if brightness == nil { log.error("DisplayServices unavailable: brightness keys stay with the system") }
    }

    private func startKeyTap() {
        let tap = MediaKeyTap { [weak self] press in self?.handleKey(press) ?? false }
        keyTap = tap
        if tap.start() { return }

        Permissions.requestAccessibility()
        // права выдают в настройках без перезапуска приложения: ждём и пробуем снова
        // таймер гасим через свойство: захват timer в assumeIsolated Swift 6 считает гонкой
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Permissions.isAccessibilityTrusted, self.keyTap?.start() == true else { return }
                self.trustTimer?.invalidate()
                self.trustTimer = nil
            }
        }
    }

    /// true — клавиша наша, системе её не отдаём.
    /// Вызывается прямо из колбэка tap на главном потоке: только быстрые вызовы, без ожиданий
    private func handleKey(_ press: MediaKeyPress) -> Bool {
        switch press.key {
        case .volumeUp, .volumeDown:
            if press.isDown, let volume {
                let before = volume.volume
                volume.step(up: press.key == .volumeUp, fine: press.fine)
                // на границе (100% и вверх, 0% и вниз) CoreAudio не меняется и слушатель молчит: HUD шлём сами.
                // step всегда снимает mute, поэтому volume здесь равен уровню, который отдал бы слушатель
                let after = volume.volume
                if after == before { store.send(.hudChanged(.volume, level: after ?? 0)) }
            }
            return true
        case .mute:
            if press.isDown, !press.isRepeat { volume?.toggleMute() }
            return true
        case .brightnessUp, .brightnessDown:
            guard let brightness else { return false }
            guard press.isDown else { return true }
            // DisplayServices не смог прочитать или выставить яркость: отдаём клавишу системе
            guard let level = brightness.step(up: press.key == .brightnessUp, fine: press.fine) else { return false }
            store.send(.hudChanged(.brightness, level: level))
            return true
        }
    }
}
