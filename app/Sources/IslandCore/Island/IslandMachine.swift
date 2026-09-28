/// Таймеры машины. Новый schedule с тем же id отменяет прежний
public enum TimerID: Hashable, Sendable {
    case peekEnd, hudHide, grow
    /// Отклик на hover раскрывается в плеер
    case hoverOpen
    /// Курсор ушёл из раскрытого: схлопывание с задержкой
    case hoverLeave
    /// Уведомление отслужило свой срок
    case alertHide
}

public enum IslandEvent: Equatable, Sendable {
    case trackChanged
    case mediaCleared
    case hudChanged(HUDKind, level: Double)
    case alertArrived(IslandAlert)
    case hoverEntered, hoverExited
    case clicked, clickedOutside
    /// На экране с вырезом открылось или закрылось полноэкранное приложение
    case fullscreenChanged(Bool)
    case timerFired(TimerID)
}

public enum IslandEffect: Equatable, Sendable {
    case animate(IslandTransition)
    case schedule(TimerID, after: Duration)
    case cancel(TimerID)
    /// Звук уведомления: играет store, если звуки включены в настройках
    case play(IslandSound)
}

public struct IslandModel: Equatable, Sendable {
    public var config: IslandMachine.Config
    public var surface: Surface = .idle
    public var hasMedia = false
    /// Куда остров раскроется, когда закончится сжатие
    public var pending: Surface?
    /// На экране с вырезом полноэкранное приложение: музыка в покое не показывается
    public var isFullscreen = false
    /// Курсор ушёл из раскрытого (режим пользователя): ждём таймер hoverLeave, возврат его отменяет
    public var leaving = false
    /// Уведомления ждут конца HUD или текущего уведомления: по приоритету, при равном — по приходу
    public var alertQueue: [IslandAlert] = []

    /// Повтор того же вида заменяет ждущее
    mutating func enqueue(_ alert: IslandAlert) {
        alertQueue.removeAll { $0.kind == alert.kind }
        let index = alertQueue.firstIndex { $0.priority < alert.priority } ?? alertQueue.endIndex
        alertQueue.insert(alert, at: index)
    }

    mutating func dequeueAlert() -> IslandAlert? {
        alertQueue.isEmpty ? nil : alertQueue.removeFirst()
    }

    public init(config: IslandMachine.Config = .user) {
        self.config = config
    }

    /// Состояние покоя: компакт при музыке только в режиме compactAtRest и не в полноэкранном, иначе форма выреза
    public var base: Surface { hasMedia && config.compactAtRest && !isFullscreen ? .compact : .idle }
}

/// Чистая машина состояний острова: приоритеты и хореография смены активностей.
/// Приоритет: HUD > уведомления > раскрытый (Duo/плеер) > hover и отклик на него > peek > компакт > покой
public enum IslandMachine {
    /// Поведение, которое отличает наш режим от Alcove. Эталон сверки записан
    /// в режиме Alcove, поэтому оба поведения — настройка, а не замена
    public struct Config: Equatable, Sendable {
        /// Hover сразу раскрывает expanded (по умолчанию — Duo, полный плеер по свайпу). Выключено:
        /// hover даёт мини-состояние, раскрытие — по клику
        public var hoverOpensPlayer: Bool
        /// При музыке остров стоит в компакте. Выключено: компакт только на время peek, в покое форма выреза
        public var compactAtRest: Bool

        /// Во сколько раз анимации острова медленнее замеров Alcove: пружины (IslandMotion) и таймеры,
        /// привязанные к их длине (сжатие перед grow). Характер пружины (ζ) тот же
        public var timeScale: Double
        /// Hover duration Alcove (0…0.6 с): сколько курсор держится над островом до раскрытия.
        /// Ноль — плеер сразу, без промежуточного отклика: так у нативного Alcove по умолчанию.
        /// Ненулевая задержка — отклик hoverNudge на это время. Замедляется timeScale
        public var hoverDelay: Duration
        /// Expand on hover (General). Выключено: hover даёт только отклик без таймера, раскрывает клик.
        /// Так ведёт себя Alcove 1.7.7 (ui-inspection 3.4, «Hover при Expand on hover = выкл»)
        public var expandsOnHover: Bool

        public init(
            hoverOpensPlayer: Bool, compactAtRest: Bool, timeScale: Double = 1, hoverDelay: Duration = .zero,
            expandsOnHover: Bool = true
        ) {
            self.hoverOpensPlayer = hoverOpensPlayer
            self.compactAtRest = compactAtRest
            self.timeScale = timeScale
            self.hoverDelay = hoverDelay
            self.expandsOnHover = expandsOnHover
        }

        /// Настройки General: Expand on hover и Hover duration (0…0.6 с, шаг 0.1 в окне настроек)
        public func applying(expandOnHover: Bool, hoverDuration: Double) -> Config {
            var config = self
            config.expandsOnHover = expandOnHover
            // NaN/inf не проходят Int(): читаем как 0, а не роняем машину настройками из UI
            let duration = hoverDuration.isFinite ? hoverDuration : 0
            config.hoverDelay = .milliseconds(Int((min(max(duration, 0), 0.6) * 1000).rounded()))
            return config
        }

        /// Режим пользователя: hover раскрывает плеер, при музыке в покое компакт, как у Alcove.
        /// Покой в форме выреза пробовали и отказались: остаётся настройкой compactAtRest = false.
        /// Анимации на 18% медленнее Alcove: по живой проверке замеренные казались слишком быстрыми
        public static let user = Config(hoverOpensPlayer: true, compactAtRest: true, timeScale: 1.18)
        /// Поведение Alcove, с которым записан эталон: для demo-прогона и сверки, пружины как в замерах
        public static let alcove = Config(hoverOpensPlayer: false, compactAtRest: true)
    }

    public static func reduce(_ model: inout IslandModel, _ event: IslandEvent) -> [IslandEffect] {
        switch event {
        case .trackChanged: trackChanged(&model)
        case .mediaCleared: mediaCleared(&model)
        case let .hudChanged(kind, level): hudChanged(&model, .hud(kind, level: level))
        case let .alertArrived(alert): alertArrived(&model, alert)
        case .hoverEntered:
            model.config.hoverOpensPlayer ? nudge(&model) : open(&model, to: .hover, with: .hoverOpen)
        case .clicked: open(&model, to: .expanded, with: .expand)
        case .hoverExited: model.config.hoverOpensPlayer ? leave(&model) : close(&model)
        case .clickedOutside: close(&model)
        case let .fullscreenChanged(on): fullscreenChanged(&model, on)
        case let .timerFired(id): timerFired(&model, id)
        }
    }

    private static func trackChanged(_ m: inout IslandModel) -> [IslandEffect] {
        m.hasMedia = true
        // после сжатия остров вернётся в покой, а покой зависит от музыки
        if m.pending == .idle || m.pending == .compact { m.pending = m.base }
        switch m.surface {
        case .idle where m.isFullscreen:
            // в полноэкранном музыка только запоминается: компакт появится после выхода
            return []
        case .idle where m.pending == nil && m.config.compactAtRest:
            m.surface = .compact
            return [.animate(.compactIn)]
        case .idle where m.pending == nil:
            // без компакта в покое смена трека коротко показывает peek и уходит обратно в форму выреза
            m.surface = .peek
            return [.animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek)]
        case .compact where m.pending == nil:
            m.surface = .peek
            return [.animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek)]
        default:
            // peek не перезапускаем, в остальных состояниях меняется только контент
            return []
        }
    }

    /// В полноэкранном компакт и peek музыки прячутся, открытый плеер и HUD не трогаем:
    /// они закроются в покой, который теперь форма выреза
    private static func fullscreenChanged(_ m: inout IslandModel, _ on: Bool) -> [IslandEffect] {
        guard m.isFullscreen != on else { return [] }
        m.isFullscreen = on
        if m.pending == .idle || m.pending == .compact { m.pending = m.base }
        switch m.surface {
        case .compact where on, .peek where on:
            m.surface = .idle
            return [.cancel(.peekEnd), .animate(.compactOut)]
        case .idle where !on && m.pending == nil && m.base == .compact:
            m.surface = .compact
            return [.animate(.compactIn)]
        default:
            return []
        }
    }

    private static func mediaCleared(_ m: inout IslandModel) -> [IslandEffect] {
        m.hasMedia = false
        if m.pending == .compact { m.pending = m.base }
        switch m.surface {
        case .compact, .peek:
            m.surface = .idle
            return [.cancel(.peekEnd), .animate(.compactOut)]
        default:
            return []
        }
    }

    private static func hudChanged(_ m: inout IslandModel, _ hud: Surface) -> [IslandEffect] {
        if case let .hoverNudge(from) = m.surface {
            // раскрытие отменяется, HUD приходит как из исходного состояния
            m.surface = from
            return [.cancel(.hoverOpen)] + hudChanged(&m, hud)
        }
        if m.leaving {
            m.leaving = false
            return [.cancel(.hoverLeave)] + hudChanged(&m, hud)
        }
        if m.pending != nil {
            // идёт сжатие: HUD покажется, когда оно закончится. Активные действия вытесняют другие: если сжатие
            // шло к уведомлению, оно просто пропадает, не уходя в очередь (решение — HUD важнее уведомления всегда)
            m.pending = hud
            return []
        }
        switch m.surface {
        case .hud:
            m.surface = hud
            return [.animate(.hudUpdate), .schedule(.hudHide, after: IslandTiming.hudVisible)]
        case .idle:
            m.surface = hud
            return [.animate(.hudIn), .schedule(.hudHide, after: IslandTiming.hudVisible)]
        // HUD важнее уведомления: уведомление уходит через сжатие и не возвращается
        case .compact, .peek, .alert:
            return shrink(&m, then: hud)
        case .hover, .expanded:
            // раскрытый морфится прямо в HUD, без схлопывания и сжатия (осмотр нативного Alcove 26.09).
            // После HUD плеер не возвращается: hudHide уводит в покой
            m.surface = hud
            return [.animate(.hudMorph), .schedule(.hudHide, after: IslandTiming.hudVisible)]
        case .shrink:
            m.pending = hud
            return []
        case .hoverNudge:
            return []
        }
    }

    /// Уведомление: из покоя сразу, из компакта через сжатие, из раскрытого морфом, как HUD (решение 27.09).
    /// Во время HUD и уведомления другого вида ждёт в очереди. Тот же вид обновляет показанное и продлевает его
    private static func alertArrived(_ m: inout IslandModel, _ alert: IslandAlert) -> [IslandEffect] {
        if case let .hoverNudge(from) = m.surface {
            m.surface = from
            return [.cancel(.hoverOpen)] + alertArrived(&m, alert)
        }
        if m.leaving {
            m.leaving = false
            return [.cancel(.hoverLeave)] + alertArrived(&m, alert)
        }
        if let pending = m.pending {
            switch pending {
            case .hud:
                m.enqueue(alert)
            case let .alert(next) where next.kind != alert.kind:
                // сжатие уже идёт к другому уведомлению: новое ждёт своей очереди
                m.enqueue(alert)
            default:
                m.pending = .alert(alert)
            }
            return []
        }
        switch m.surface {
        case .idle:
            m.surface = .alert(alert)
            return [.animate(.alertIn)] + shown(alert)
        case let .alert(current) where current.kind == alert.kind:
            m.surface = .alert(alert)
            return [.animate(.alertUpdate), .schedule(.alertHide, after: alert.duration)]
        case .alert, .hud:
            m.enqueue(alert)
            return []
        case .compact, .peek:
            return shrink(&m, then: .alert(alert))
        case .hover, .expanded:
            m.surface = .alert(alert)
            return [.animate(.hudMorph)] + shown(alert)
        case .shrink, .hoverNudge:
            // сжатие всегда с pending, отклик разобран выше
            return []
        }
    }

    /// Уведомление появилось на экране: таймер ухода и звук
    private static func shown(_ alert: IslandAlert) -> [IslandEffect] {
        [.schedule(.alertHide, after: alert.duration)] + (alert.sound.map { [IslandEffect.play($0)] } ?? [])
    }

    private static func open(_ m: inout IslandModel, to target: Surface, with transition: IslandTransition) -> [IslandEffect] {
        guard m.pending == nil else { return [] }
        switch m.surface {
        case .idle, .compact, .peek: break
        case .hover where target == .expanded: break
        case .hoverNudge where target == .expanded:
            // клик во время отклика раскрывает сразу, не дожидаясь таймера
            m.surface = target
            return [.cancel(.hoverOpen), .animate(transition)]
        default: return []
        }
        m.surface = target
        return [.cancel(.peekEnd), .animate(transition)]
    }

    /// Hover в режиме пользователя: из покоя, компакта и peek плеер сразу, а при ненулевой hoverDelay —
    /// сначала отклик и плеер по таймеру hoverOpen. Возврат курсора, пока раскрытый ждёт схлопывания, отменяет его
    private static func nudge(_ m: inout IslandModel) -> [IslandEffect] {
        if m.leaving {
            m.leaving = false
            return [.cancel(.hoverLeave)]
        }
        guard m.pending == nil else { return [] }
        switch m.surface {
        case .idle, .compact, .peek:
            if m.config.expandsOnHover, m.config.hoverDelay == .zero {
                m.surface = .expanded
                return [.cancel(.peekEnd), .animate(.hoverExpand)]
            }
            m.surface = .hoverNudge(from: m.surface)
            // Expand on hover выключен: отклик держится, пока курсор над островом, раскрывает клик
            guard m.config.expandsOnHover else { return [.cancel(.peekEnd), .animate(.hoverNudge)] }
            return [
                .cancel(.peekEnd), .animate(.hoverNudge),
                .schedule(.hoverOpen, after: m.config.hoverDelay * m.config.timeScale),
            ]
        default:
            return []
        }
    }

    /// Уход курсора в режиме пользователя: отклик возвращается в покой сразу, раскрытый — после задержки
    private static func leave(_ m: inout IslandModel) -> [IslandEffect] {
        switch m.surface {
        case let .hoverNudge(from):
            m.surface = m.base
            return [.cancel(.hoverOpen), .animate(settle(from: from, to: m.surface))]
        case .hover, .expanded:
            guard !m.leaving else { return [] }
            m.leaving = true
            return [.schedule(.hoverLeave, after: IslandTiming.hoverLeave * m.config.timeScale)]
        default:
            return []
        }
    }

    /// Переход из отклика обратно в покой. Покой мог смениться за время отклика (трек, полноэкранный)
    private static func settle(from: Surface, to base: Surface) -> IslandTransition {
        switch (from, base) {
        case _ where from == base: .hoverNudgeBack
        case (.peek, .compact): .peekClose
        case (_, .compact): .compactIn
        default: .compactOut
        }
    }

    private static func close(_ m: inout IslandModel) -> [IslandEffect] {
        guard m.surface == .hover || m.surface == .expanded else { return [] }
        m.surface = m.base
        if m.leaving {
            m.leaving = false
            return [.cancel(.hoverLeave), .animate(.collapse)]
        }
        return [.animate(.collapse)]
    }

    private static func timerFired(_ m: inout IslandModel, _ id: TimerID) -> [IslandEffect] {
        switch id {
        case .peekEnd:
            guard m.surface == .peek else { return [] }
            m.surface = m.base
            // peek → покой берёт пружину ухода компакта: это тот же уход живой активности в вырез,
            // и у него есть замер (261 → 186). peekClose — сжатие peek в компакт, его подгонка
            // в задаче 16 по эталону не должна менять уход в вырез
            return [.animate(m.surface == .compact ? .peekClose : .compactOut)]
        case .hudHide:
            guard case .hud = m.surface, m.pending == nil else { return [] }
            if let alert = m.dequeueAlert() { return shrink(&m, then: .alert(alert)) }
            if m.base == .compact { return shrink(&m, then: .compact) }
            m.surface = .idle
            return [.animate(.hudOut)]
        case .grow:
            guard m.surface == .shrink, let target = m.pending else { return [] }
            m.pending = nil
            m.surface = target
            if case let .alert(alert) = target { return [.animate(.alertGrow)] + shown(alert) }
            if case .hud = target {
                return [.animate(.grow), .schedule(.hudHide, after: IslandTiming.hudVisible)]
            }
            return [.animate(.grow)]
        case .hoverOpen:
            // настройку могли выключить, пока таймер уже стоял в очереди: не раскрываем задним числом
            guard m.config.expandsOnHover, case .hoverNudge = m.surface, m.pending == nil else { return [] }
            m.surface = .expanded
            return [.animate(.hoverExpand)]
        case .hoverLeave:
            guard m.leaving else { return [] }
            // таймер уже сработал: отменять нечего
            m.leaving = false
            return close(&m)
        case .alertHide:
            guard case .alert = m.surface, m.pending == nil else { return [] }
            if let next = m.dequeueAlert() { return shrink(&m, then: .alert(next)) }
            if m.base == .compact { return shrink(&m, then: .compact) }
            m.surface = .idle
            return [.animate(.alertOut)]
        }
    }

    /// Смена активности: сжатие почти до выреза, раскрытие в target по таймеру grow
    private static func shrink(_ m: inout IslandModel, then target: Surface) -> [IslandEffect] {
        let transition = shrinkTransition(from: m.surface)
        m.surface = .shrink
        m.pending = target
        return [.cancel(.peekEnd), .animate(transition), .schedule(.grow, after: IslandTiming.shrink * m.config.timeScale)]
    }

    /// Пружина сжатия выбирается по исходному состоянию: у Alcove сжатие из компакта (261 → ~195)
    /// пружинит (345/30.5, ζ 0.82), а из широкого HUD (369 → ~199) идёт без отскока (360/38).
    /// Каждый новый широкий источник (alert, календарь) добавляет сюда свой case со своим замером
    /// (пример — .alert → .alertShrink), а не попадает молча в пружину компакта: switch без default
    private static func shrinkTransition(from source: Surface) -> IslandTransition {
        switch source {
        case .hud: .shrinkFromWide
        // замер записи №2 (capture/analysis/README.md): Charging → сжатие 335/37
        case .alert: .alertShrink
        // hoverNudge разворачивается в исходный компакт или peek до сжатия (hudChanged, alertArrived)
        case .compact, .peek, .hoverNudge: .shrink
        // отсюда сжатия нет: покой показывает HUD сразу, раскрытый морфится, сжатие уже идёт
        case .idle, .hover, .expanded, .shrink: .shrink
        }
    }
}
