/// Таймеры машины. Новый schedule с тем же id отменяет прежний
public enum TimerID: Hashable, Sendable {
    case peekEnd, hudHide, grow, collapseDone
}

public enum IslandEvent: Equatable, Sendable {
    case trackChanged
    case mediaCleared
    case hudChanged(HUDKind, level: Double)
    case hoverEntered, hoverExited
    case clicked, clickedOutside
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

    public init(config: IslandMachine.Config = .user) {
        self.config = config
    }

    /// Состояние покоя: компакт при музыке только в режиме compactAtRest, иначе форма выреза
    public var base: Surface { hasMedia && config.compactAtRest ? .compact : .idle }
}

/// Чистая машина состояний острова: приоритеты и хореография смены активностей.
/// Приоритет: HUD > раскрытый плеер > hover > peek > компакт > покой
public enum IslandMachine {
    /// Поведение, которое отличает наш режим от Alcove. Эталон сверки (задачи 15–16) записан
    /// в режиме Alcove, поэтому оба поведения — настройка, а не замена
    public struct Config: Equatable, Sendable {
        /// Hover сразу раскрывает полный плеер. Выключено: hover даёт мини-состояние, плеер по клику
        public var hoverOpensPlayer: Bool
        /// При музыке остров стоит в компакте. Выключено: компакт только на время peek, в покое форма выреза
        public var compactAtRest: Bool

        public init(hoverOpensPlayer: Bool, compactAtRest: Bool) {
            self.hoverOpensPlayer = hoverOpensPlayer
            self.compactAtRest = compactAtRest
        }

        /// Режим пользователя: hover раскрывает плеер, при музыке в покое компакт, как у Alcove.
        /// Покой в форме выреза пробовали и отказались: остаётся настройкой compactAtRest = false
        public static let user = Config(hoverOpensPlayer: true, compactAtRest: true)
        /// Поведение Alcove, с которым записан эталон: для demo-прогона и сверки
        public static let alcove = Config(hoverOpensPlayer: false, compactAtRest: true)
    }

    public static func reduce(_ model: inout IslandModel, _ event: IslandEvent) -> [IslandEffect] {
        switch event {
        case .trackChanged: trackChanged(&model)
        case .mediaCleared: mediaCleared(&model)
        case let .hudChanged(kind, level): hudChanged(&model, .hud(kind, level: level))
        case .hoverEntered:
            model.config.hoverOpensPlayer
                ? open(&model, to: .expanded, with: .hoverExpand)
                : open(&model, to: .hover, with: .hoverOpen)
        case .clicked: open(&model, to: .expanded, with: .expand)
        case .hoverExited, .clickedOutside: close(&model)
        case let .timerFired(id): timerFired(&model, id)
        }
    }

    private static func trackChanged(_ m: inout IslandModel) -> [IslandEffect] {
        m.hasMedia = true
        // после сжатия или схлопывания остров вернётся в покой, а покой зависит от музыки
        if m.pending == .idle || m.pending == .compact { m.pending = m.base }
        switch m.surface {
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
            return [.animate(.collapse), .schedule(.collapseDone, after: IslandTiming.collapse)]
        case .shrink:
            m.pending = hud
            return []
        }
    }

    private static func open(_ m: inout IslandModel, to target: Surface, with transition: IslandTransition) -> [IslandEffect] {
        guard m.pending == nil else { return [] }
        switch m.surface {
        case .idle, .compact, .peek: break
        case .hover where target == .expanded: break
        default: return []
        }
        m.surface = target
        return [.cancel(.peekEnd), .animate(transition)]
    }

    private static func close(_ m: inout IslandModel) -> [IslandEffect] {
        guard m.surface == .hover || m.surface == .expanded else { return [] }
        m.surface = m.base
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
        return [.cancel(.peekEnd), .animate(.shrink), .schedule(.grow, after: IslandTiming.shrink)]
    }
}
