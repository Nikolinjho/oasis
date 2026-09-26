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
    public var surface: Surface = .idle
    public var hasMedia = false
    /// Куда остров раскроется, когда закончится сжатие или схлопывание
    public var pending: Surface?

    public init() {}

    /// Состояние покоя: компакт, если есть музыка
    public var base: Surface { hasMedia ? .compact : .idle }
}

/// Чистая машина состояний острова: приоритеты и хореография смены активностей.
/// Приоритет: HUD > раскрытый плеер > hover > peek > компакт > покой
public enum IslandMachine {
    public static func reduce(_ model: inout IslandModel, _ event: IslandEvent) -> [IslandEffect] {
        switch event {
        case .trackChanged: trackChanged(&model)
        case .mediaCleared: mediaCleared(&model)
        case let .hudChanged(kind, level): hudChanged(&model, .hud(kind, level: level))
        case .hoverEntered: open(&model, to: .hover, with: .hoverOpen)
        case .clicked: open(&model, to: .expanded, with: .expand)
        case .hoverExited, .clickedOutside: close(&model)
        case let .timerFired(id): timerFired(&model, id)
        }
    }

    private static func trackChanged(_ m: inout IslandModel) -> [IslandEffect] {
        m.hasMedia = true
        if m.pending == .idle { m.pending = .compact }
        switch m.surface {
        case .idle where m.pending == nil:
            m.surface = .compact
            return [.animate(.compactIn)]
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
        if m.pending == .compact { m.pending = .idle }
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
            m.surface = .compact
            return [.animate(.peekClose)]
        case .hudHide:
            guard case .hud = m.surface, m.pending == nil else { return [] }
            if m.hasMedia { return shrink(&m, then: .compact) }
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
