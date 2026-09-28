/// Переходы острова: у каждого своя пружина
public enum IslandTransition: Equatable, Sendable {
    case compactIn, compactOut
    case peekOpen, peekClose
    /// hoverOpen — hover в мини-состояние (режим Alcove), hoverExpand — hover сразу в полный плеер
    case hoverOpen, hoverExpand, expand, collapse
    /// Отклик на hover перед раскрытием (режим пользователя) и возврат из него, если курсор ушёл раньше
    case hoverNudge, hoverNudgeBack
    case hudIn, hudOut, hudUpdate
    /// Раскрытый остров перетекает прямо в HUD
    case hudMorph
    /// Сжатие почти до выреза перед сменой активности и раскрытие в новую.
    /// shrinkFromHud — то же сжатие из HUD обратно к компакту: у Alcove у него своя пружина
    case shrink, shrinkFromHud, grow

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
        // оценка: пружину отклика не подгоняли, отклик прерывается раскрытием через ~130 мс,
        // и по кадрам видно только монотонный рост ширины. Мягкая без отскока, та же в обе стороны.
        // На сайте hover — scale 1.075 пружиной 250/14 (motion.md), в нативном отскока не видно
        case .hoverNudge, .hoverNudgeBack: .smooth(duration: 0.13)
        case .hudIn: .smooth(duration: 0.44)
        case .hudOut: .smooth(duration: 0.45)
        // оценка: пружину не подгоняли. Осмотр 26.09 (случайная запись): 175 → 32 за ~0.35 с,
        // ширина с перелётом выше конечной. Берём замеренную пружину hover-открытия, у неё тот же перелёт
        case .hudMorph: SpringSpec(stiffness: 200, damping: 17.5)
        // новый уровень HUD меняет только полоску, размер тот же
        case .hudUpdate: nil
        // замеры сжатия перед сменой (analysis/README.md): из компакта 261 → ~195 — 345/30.5,
        // из HUD 369 → ~199 — 360/38. Одна .smooth(0.33) (≈ 362/38) давала сжатию перед HUD
        // на 2.6 pt меньше хода к моменту раскрытия (demo-сверка 28.09)
        case .shrink: SpringSpec(stiffness: 345, damping: 30.5)
        case .shrinkFromHud: SpringSpec(stiffness: 360, damping: 38)
        case .grow: .spring(duration: 0.45, bounce: 0.1)
        }
    }
}
