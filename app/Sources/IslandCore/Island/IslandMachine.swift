/// Таймеры машины. Новый schedule с тем же id отменяет прежний
public enum TimerID: Hashable, Sendable {
    case peekEnd, hudHide, grow, collapseDone
    /// Отклик на hover раскрывается в плеер
    case hoverOpen
    /// Курсор ушёл из раскрытого: схлопывание с задержкой
    case hoverLeave
}

public enum IslandEvent: Equatable, Sendable {
    case trackChanged
    case mediaCleared
    case hudChanged(HUDKind, level: Double)
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
}

public struct IslandModel: Equatable, Sendable {
    public var config: IslandMachine.Config
    public var surface: Surface = .idle
    public var hasMedia = false
    /// Куда остров раскроется, когда закончится сжатие или схлопывание
    public var pending: Surface?
    /// На экране с вырезом полноэкранное приложение: музыка в покое не показывается
    public var isFullscreen = false
    /// Курсор ушёл из раскрытого (режим пользователя): ждём таймер hoverLeave, возврат его отменяет
    public var leaving = false

    public init(config: IslandMachine.Config = .user) {
        self.config = config
    }

    /// Состояние покоя: компакт при музыке только в режиме compactAtRest и не в полноэкранном, иначе форма выреза
    public var base: Surface { hasMedia && config.compactAtRest && !isFullscreen ? .compact : .idle }
}

/// Чистая машина состояний острова: приоритеты и хореография смены активностей.
/// Приоритет: HUD > раскрытый плеер > hover и отклик на него > peek > компакт > покой
public enum IslandMachine {
    /// Поведение, которое отличает наш режим от Alcove. Эталон сверки (задачи 15–16) записан
    /// в режиме Alcove, поэтому оба поведения — настройка, а не замена
    public struct Config: Equatable, Sendable {
        /// Hover сразу раскрывает полный плеер. Выключено: hover даёт мини-состояние, плеер по клику
        public var hoverOpensPlayer: Bool
        /// При музыке остров стоит в компакте. Выключено: компакт только на время peek, в покое форма выреза
        public var compactAtRest: Bool

        /// Во сколько раз анимации острова медленнее замеров Alcove: пружины (IslandMotion) и таймеры,
        /// привязанные к их длине (сжатие перед grow, схлопывание перед HUD). Характер пружины (ζ) тот же
        public var timeScale: Double

        public init(hoverOpensPlayer: Bool, compactAtRest: Bool, timeScale: Double = 1) {
            self.hoverOpensPlayer = hoverOpensPlayer
            self.compactAtRest = compactAtRest
            self.timeScale = timeScale
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
        // после сжатия или схлопывания остров вернётся в покой, а покой зависит от музыки
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
            // идёт сжатие или схлопывание: HUD покажется, когда оно закончится
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
        case .compact, .peek:
            return shrink(&m, then: hud)
        case .hover, .expanded:
            // сначала закрываемся, потом HUD появляется как из закрытого состояния
            m.surface = m.base
            m.pending = hud
            return [.animate(.collapse), .schedule(.collapseDone, after: IslandTiming.collapse * m.config.timeScale)]
        case .shrink:
            m.pending = hud
            return []
        case .hoverNudge:
            return []
        }
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

    /// Hover в режиме пользователя: из покоя, компакта и peek сначала отклик, плеер по таймеру hoverOpen.
    /// Возврат курсора, пока раскрытый ждёт схлопывания, отменяет его
    private static func nudge(_ m: inout IslandModel) -> [IslandEffect] {
        if m.leaving {
            m.leaving = false
            return [.cancel(.hoverLeave)]
        }
        guard m.pending == nil else { return [] }
        switch m.surface {
        case .idle, .compact, .peek:
            m.surface = .hoverNudge(from: m.surface)
            return [
                .cancel(.peekEnd), .animate(.hoverNudge),
                .schedule(.hoverOpen, after: IslandTiming.hoverNudge * m.config.timeScale),
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
            if m.base == .compact { return shrink(&m, then: .compact) }
            m.surface = .idle
            return [.animate(.hudOut)]
        case .grow:
            guard m.surface == .shrink, let target = m.pending else { return [] }
            m.pending = nil
            m.surface = target
            if case .hud = target {
                return [.animate(.grow), .schedule(.hudHide, after: IslandTiming.hudVisible)]
            }
            return [.animate(.grow)]
        case .hoverOpen:
            guard case .hoverNudge = m.surface, m.pending == nil else { return [] }
            m.surface = .expanded
            return [.animate(.hoverExpand)]
        case .hoverLeave:
            guard m.leaving else { return [] }
            // таймер уже сработал: отменять нечего
            m.leaving = false
            return close(&m)
        case .collapseDone:
            guard m.surface != .shrink, let target = m.pending else { return [] }
            m.pending = nil
            return hudChanged(&m, target)
        }
    }

    /// Смена активности: сжатие почти до выреза, раскрытие в target по таймеру grow
    private static func shrink(_ m: inout IslandModel, then target: Surface) -> [IslandEffect] {
        m.surface = .shrink
        m.pending = target
        return [.cancel(.peekEnd), .animate(.shrink), .schedule(.grow, after: IslandTiming.shrink * m.config.timeScale)]
    }
}
