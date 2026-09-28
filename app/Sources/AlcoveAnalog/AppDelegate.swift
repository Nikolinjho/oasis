import AppKit
import IslandCore
import IslandSources
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private let settings = AppSettings()
    private var window: IslandWindowController?
    private var statusItem: StatusItemController?
    private var nowPlaying: AdapterNowPlayingSource?
    private var volume: VolumeControl?
    private var brightness: BrightnessControl?
    private var keyTap: MediaKeyTap?
    private var trustTimer: Timer?
    private var fullscreen: FullscreenMonitor?
    private var calendar: EventKitCalendarSource?
    private var power: PowerSource?
    private var lastPower: PowerState?
    private var tasks: [Task<Void, Never>] = []
    private var debugSections: [DebugSection] = []
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "app")

    /// При холодном запуске по ссылке (`open -g -a … "alcove-analog://…"`) AppKit доставляет
    /// application(_:open:) ещё до applicationDidFinishLaunching: каталог должен быть готов уже здесь
    func applicationWillFinishLaunching(_ notification: Notification) {
        debugSections = DebugCatalog.sections(store: store)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.config = settings.machineConfig(from: store.config)
        settings.onChange = { [weak self] in self?.applySettings() }
        // статус-айтем раньше окна: остров открывает его меню по правому клику
        let statusItem = StatusItemController(
            debugItem: DebugMenu.item(sections: debugSections),
            isTrusted: { Permissions.isAccessibilityTrusted })
        self.statusItem = statusItem
        window = IslandWindowController(store: store, menu: statusItem.menu)
        if let delay = DemoSequence.launchDelay(arguments: CommandLine.arguments) {
            // живые источники мешали бы записи: не стартуют startFullscreenMonitor, startNowPlaying
            // (адаптер медиа), startPlayerActions, startLevels (CoreAudio HUD громкости/яркости), startKeyTap
            log.info("demo mode after \(delay, privacy: .public) s")
            DemoSequence.run(store: store, after: delay)
            return
        }
        startFullscreenMonitor()
        startNowPlaying()
        startPlayerActions()
        startCalendar()
        startPower()
        startLevels()
        startKeyTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.stop()
    }

    /// Настройки меняются на лету из окна настроек и меню: машина подхватывает их сразу.
    /// Выбор экрана (DisplayChoice) пока не влияет на окно — это отдельная задача
    private func applySettings() {
        store.config = settings.machineConfig(from: store.config)
    }

    /// alcove-analog://debug/<id>: то же действие, что пункт меню Debug
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let id = DebugURL.actionID(from: url) else {
                DebugAction.log.error("unknown url \(url.absoluteString, privacy: .public)")
                continue
            }
            guard let action = debugSections.lazy.flatMap(\.actions).first(where: { $0.id == id }) else {
                DebugAction.log.error("unknown id \(id, privacy: .public)")
                continue
            }
            action.perform()
        }
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

    private func startCalendar() {
        let source = EventKitCalendarSource()
        tasks.append(Task { [store] in
            for await events in source.changes { store.apply(events: events) }
        })
        source.start()
        calendar = source
    }

    private func startPower() {
        let power = PowerSource()
        power.onChange = { [weak self] state in
            guard let self else { return }
            for alert in PowerNotices.alerts(from: lastPower, to: state) { store.send(.alertArrived(alert)) }
            lastPower = state
        }
        power.start()
        self.power = power
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
