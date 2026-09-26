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
    public static func spring(for transition: IslandTransition) -> SpringSpec? {
        switch transition {
        case .compactIn: SpringSpec(stiffness: 235, damping: 31)
        case .compactOut: SpringSpec(stiffness: 185, damping: 27.5)
        // peek не мерили: берём пружины компакта
        case .peekOpen: SpringSpec(stiffness: 235, damping: 31)
        case .peekClose: SpringSpec(stiffness: 185, damping: 27.5)
        // hover не мерили: берём пружину раскрытия по клику. Замер hover-раскрытия по видео Alcove
        // ожидается, тогда меняются только эти строки
        case .hoverOpen, .hoverExpand, .expand: SpringSpec(stiffness: 175, damping: 16)
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
