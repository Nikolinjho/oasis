/// Переходы острова: у каждого своя пружина
public enum IslandTransition: Equatable, Sendable {
    case compactIn, compactOut
    case peekOpen, peekClose
    /// hoverOpen — hover в мини-состояние (режим Alcove), hoverExpand — hover сразу в полный плеер
    case hoverOpen, hoverExpand, expand, collapse
    case hudIn, hudOut, hudUpdate
    /// Сжатие почти до выреза перед сменой активности и раскрытие в новую
    case shrink, grow

    /// Остров раскрылся наведением курсора: на это приложение отвечает тактильным откликом
    public var opensByHover: Bool { self == .hoverOpen || self == .hoverExpand }
}

/// Пружины переходов. Числа — замеры нативного Alcove из capture/analysis/README.md
public enum IslandMotion {
    /// Пружина перехода, замедленная в timeScale раз (IslandMachine.Config.timeScale)
    public static func spring(for transition: IslandTransition, timeScale: Double) -> SpringSpec? {
        spring(for: transition)?.slowed(by: timeScale)
    }

    public static func spring(for transition: IslandTransition) -> SpringSpec? {
        switch transition {
        case .compactIn: SpringSpec(stiffness: 235, damping: 31)
        case .compactOut: SpringSpec(stiffness: 185, damping: 27.5)
        // peek не мерили: берём пружины компакта
        case .peekOpen: SpringSpec(stiffness: 235, damping: 31)
        case .peekClose: SpringSpec(stiffness: 185, damping: 27.5)
        // hover в мини-состояние (режим Alcove) не мерили: берём пружину раскрытия по клику
        case .hoverOpen, .expand: SpringSpec(stiffness: 175, damping: 16)
        // замер видео hover-открытия Alcove 2026-09-26: 202.5/17.5, ζ ≈ 0.62, СКО 0.46 pt.
        // Ширина и высота идут одной пружиной. Схлопывание по уходу курсора — то же smooth(0.4)
        case .hoverExpand: SpringSpec(stiffness: 200, damping: 17.5)
        case .collapse: .smooth(duration: 0.4)
        case .hudIn: .smooth(duration: 0.44)
        case .hudOut: .smooth(duration: 0.45)
        // новый уровень HUD меняет только полоску, размер тот же
        case .hudUpdate: nil
        case .shrink: .smooth(duration: 0.33)
        case .grow: .spring(duration: 0.45, bounce: 0.1)
        }
    }
}
