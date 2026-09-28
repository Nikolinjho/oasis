import AppKit
import IslandCore
import IslandSources
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private let settings = AppSettings()
    private let sounds = SoundPlayer()
    private lazy var settingsWindow = SettingsWindowController(settings: settings) { [weak self] sound in
        self?.sounds.play(sound)
    }
    private var window: IslandWindowController?
    private var statusItem: StatusItemController?
    private var nowPlaying: AdapterNowPlayingSource?
    private var volume: VolumeControl?
    private var brightness: BrightnessControl?
    private var keyTap: MediaKeyTap?
    private var trustTimer: Timer?
    private var fullscreen: FullscreenMonitor?
    private var sourceActivity: SourceActivityMonitor?
    private var frontmostBundleID: String?
    private var calendar: EventKitCalendarSource?
    private lazy var calendarClock = CalendarClock(store: store)
    private var power: PowerSource?
    private var bluetooth: BluetoothWatcher?
    private var headphonesMonitor: HeadphonesBatteryMonitor?
    private var headphonesBattery = HeadphonesBatteryTracker()
    /// Нормализованный адрес → модель наушников, о которых сообщал BluetoothWatcher: глиф Show device
    private var knownHeadphones: [String: AirPodsInfo.Model?] = [:]
    private var output = OutputDeviceInfo(transport: 0, uid: "", name: "")
    private var lastPower: PowerState?
    private var tasks: [Task<Void, Never>] = []
    private var debugSections: [DebugSection] = []
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "app")

    /// При холодном запуске по ссылке (`open -g -a … "alcove-analog://…"`) AppKit доставляет
    /// application(_:open:) ещё до applicationDidFinishLaunching: каталог должен быть готов уже здесь
    func applicationWillFinishLaunching(_ notification: Notification) {
        debugSections = DebugCatalog.sections(store: store, settings: settings, sounds: sounds)
        // здесь, а не в applicationDidFinishLaunching: холодный запуск по ссылке calendar.remind закрепляет повестку раньше
        store.onAgendaChange = { [weak self] agenda in self?.calendarClock.update(agenda: agenda) }
        store.onSound = { [weak self] sound in
            guard let self, settings.playSounds else { return }
            sounds.play(sound)
        }
        store.onJoin = { [log] url in
            log.info("join \(url.host() ?? "", privacy: .public)")
            NSWorkspace.shared.open(url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.config = settings.machineConfig(from: store.config)
        applyAppearance()
        settings.onChange = { [weak self] in self?.applySettings() }
        // статус-айтем раньше окна: остров открывает его меню по правому клику
        let statusItem = StatusItemController(
            debugItem: DebugMenu.item(sections: debugSections),
            isTrusted: { Permissions.isAccessibilityTrusted },
            openSettings: { [weak self] in self?.settingsWindow.show() },
            // часы читаются только при открытии меню: lazy calendarClock создаётся при первом обращении
            calendarItems: { [weak self] in
                guard let self else { return [] }
                return CalendarMenuSection.items(for: calendarClock.menuModel(), actions: .init(
                    join: { [store] url in store.onJoin(url) },
                    open: { CalendarMenuSection.open($0) },
                    dismiss: { [calendarClock] id in calendarClock.dismiss(id) }))
            })
        self.statusItem = statusItem
        statusItem.setIconHidden(settings.hideMenuBarIcon)
        window = IslandWindowController(store: store, menu: statusItem.menu)
        window?.tuning = settings.notchTuning
        if let delay = DemoSequence.launchDelay(arguments: CommandLine.arguments) {
            // живые источники мешали бы записи: не стартуют startFullscreenMonitor, startSourceActivity, startNowPlaying
            // (адаптер медиа), startPlayerActions, startCalendar, startPower, startBluetooth, startLevels (CoreAudio HUD
            // громкости/яркости), startKeyTap
            log.info("demo mode after \(delay, privacy: .public) s")
            DemoSequence.run(store: store, after: delay)
            return
        }
        startFullscreenMonitor()
        startSourceActivity()
        startNowPlaying()
        startPlayerActions()
        startCalendar()
        startPower()
        startBluetooth()
        startLevels()
        startKeyTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.stop()
        power?.stop()
        bluetooth?.stop()
        headphonesMonitor?.stop()
    }

    /// Настройки меняются на лету из окна настроек и меню: машина подхватывает их сразу.
    /// Выбор экрана (DisplayChoice) пока не влияет на окно — это отдельная задача
    private func applySettings() {
        store.config = settings.machineConfig(from: store.config)
        applyAppearance()
        statusItem?.setIconHidden(settings.hideMenuBarIcon)
        window?.tuning = settings.notchTuning
    }

    /// Вид острова: настройки плюс текущее устройство вывода
    private func applyAppearance() {
        var appearance = settings.appearance
        appearance.output = OutputDeviceKind.classify(
            transport: output.transport, uid: output.uid, name: output.name, knownHeadphones: knownHeadphones)
        store.appearance = appearance
    }

    /// Повторный запуск (open -a, Spotlight) открывает настройки: с Hide menu bar icon при закрытой крышке
    /// иначе до них не добраться
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
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

    /// Источник музыки на переднем плане: сверяется при смене приложения и при смене трека
    private func updateSourceActive() {
        let active = frontmostBundleID != nil && frontmostBundleID == store.nowPlaying?.bundleID
        store.send(.sourceActiveChanged(active))
    }

    private func startSourceActivity() {
        let monitor = SourceActivityMonitor { [weak self] bundleID in
            self?.frontmostBundleID = bundleID
            self?.updateSourceActive()
        }
        monitor.start()
        sourceActivity = monitor
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
        tasks.append(Task { [weak self, store] in
            for await change in source.changes {
                store.apply(change)
                self?.updateSourceActive()
            }
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
            for alert in PowerNotices.alerts(from: lastPower, to: state, rules: settings.powerRules) { store.send(.alertArrived(alert)) }
            lastPower = state
        }
        power.start()
        self.power = power
    }

    private func startBluetooth() {
        let watcher = BluetoothWatcher()
        watcher.onConnect = { [weak self] info in self?.headphonesConnected(info) }
        watcher.start()
        bluetooth = watcher
        let monitor = HeadphonesBatteryMonitor()
        monitor.onReading = { [weak self] list in self?.headphonesPolled(list) }
        monitor.shouldPoll = { [weak self] in
            guard let self else { return false }
            return settings.connectivityEnabled && settings.warnHeadphonesLowBattery
        }
        monitor.start()
        headphonesMonitor = monitor
        // наушники, подключённые ещё до запуска: BluetoothWatcher считает первый снимок исходным
        // и по нему onConnect не шлёт — без этого переименованные AirPods после запуска были бы просто headphones
        tasks.append(Task { [weak self] in
            let list = await AirPodsBattery.connectedHeadphonesNow()
            self?.rememberHeadphones(list)
        })
    }

    /// Запоминает модель наушников по адресу для глифа Show device (OutputDeviceKind.classify) и обновляет вид острова
    private func rememberHeadphones(_ list: [AirPodsInfo]) {
        for info in list {
            guard let address = info.address else { continue }
            knownHeadphones[AirPodsBattery.normalized(address: address)] = info.model
        }
        applyAppearance()
    }

    /// Connectivity выключен — уведомлений нет. Заряд уже ниже порога — сразу красное кольцо и звук
    private func headphonesConnected(_ info: AirPodsInfo) {
        var info = info
        rememberHeadphones([info])
        if let address = info.address {
            let low = headphonesBattery.connected(
                address: address, level: info.battery, threshold: settings.headphonesLowBatteryThreshold)
            info.isLowBattery = low && settings.warnHeadphonesLowBattery
        }
        guard settings.connectivityEnabled else { return }
        store.send(.alertArrived(.airpods(info)))
    }

    private func headphonesPolled(_ list: [AirPodsInfo]) {
        rememberHeadphones(list)
        for var info in list {
            guard let address = info.address, let level = info.battery,
                  headphonesBattery.update(address: address, level: level, threshold: settings.headphonesLowBatteryThreshold),
                  settings.connectivityEnabled, settings.warnHeadphonesLowBattery else { continue }
            info.isLowBattery = true
            store.send(.alertArrived(.airpods(info)))
        }
    }

    private func startLevels() {
        // HUD громкости всегда идёт от слушателя CoreAudio: и в режиме перехвата, и без Accessibility.
        // Sound выключен — клавиши у системы, и изменения громкости HUD не показывают
        let volume = VolumeControl()
        tasks.append(Task { [weak self] in
            for await level in volume.changes {
                guard let self else { return }
                guard settings.soundHUDEnabled else { continue }
                store.send(.hudChanged(.volume, level: level))
            }
        })
        tasks.append(Task { [weak self] in
            for await info in volume.outputs {
                guard let self else { return }
                output = info
                applyAppearance()
            }
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
            guard settings.soundHUDEnabled else { return false }
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
            guard settings.soundHUDEnabled else { return false }
            if press.isDown, !press.isRepeat { volume?.toggleMute() }
            return true
        case .brightnessUp, .brightnessDown:
            guard settings.displayHUDEnabled, let brightness else { return false }
            guard press.isDown else { return true }
            // DisplayServices не смог прочитать или выставить яркость: отдаём клавишу системе
            guard let level = brightness.step(up: press.key == .brightnessUp, fine: press.fine) else { return false }
            store.send(.hudChanged(.brightness, level: level))
            return true
        }
    }
}
