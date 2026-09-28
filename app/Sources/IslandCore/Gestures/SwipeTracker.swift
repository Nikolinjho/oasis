import CoreGraphics
import Foundation

/// Двухпальцевый свайп над раскрытым островом (ui-inspection 3.7). Вход — фазы и дельты scrollWheel
/// (без инерции: у Alcove её нет), dy > 0 — пальцы вниз. Выход — что делать с островом
public struct SwipeTracker: Sendable {
    public enum Phase: Sendable {
        case began, changed, ended
    }

    public enum Output: Equatable, Sendable {
        /// Добавка к высоте раскрытого: вниз +, вверх −
        case stretch(CGFloat)
        /// Порог вверх пройден: схлопнуть сразу, не дожидаясь отпускания
        case close
        /// Отпустили после движения вниз: следующий вид
        case cycle
        /// Отпустили, не дотянув: вернуть высоту
        case settle
    }

    /// Сколько pt острова даёт единица дельты скролла. Подгонка по scroll-1.log и gest-1.mov.json:
    /// медиана отношения просадки высоты (столбец 3 трека) к накопленной дельте в жестах вверх
    /// до схлопывания, 155 кадров — 0.203. Время лога сдвинуто на −0.1 с: без сдвига высота
    /// в медленных жестах начинает падать за ~0.1 с до первого события лога.
    /// Та же величина объясняет флики: −140 закрыл (28 pt), −89 нет (18 pt)
    public static let pointsPerDelta: CGFloat = 0.2
    /// Сжатие вверх, после которого остров схлопывается: ~21 pt по ui-inspection 3.7 (175 → ~154).
    /// По той же подгонке в 4 медленных жестах схлопывание началось при сжатии 22–24.5 pt
    /// и накопленной дельте −119…−124 (24 pt при pointsPerDelta): 21 чуть чувствительнее записи
    public static let closeThreshold: CGFloat = 21
    /// Потолок растяжения вниз: 175 → 182 сколько ни тяни (ui-inspection 3.7)
    public static let stretchCeiling: CGFloat = 7
    /// Меньше этого вниз — не свайп, а касание. Замера нет, оценка
    public static let minimumCycle: CGFloat = 1

    private var total: CGFloat = 0
    private var closed = false

    public init() {}

    public mutating func feed(_ phase: Phase, dy: CGFloat) -> Output? {
        switch phase {
        case .began:
            total = 0
            closed = false
            return nil
        case .changed:
            guard !closed else { return nil }
            total += dy
            let travel = total * Self.pointsPerDelta
            if travel <= -Self.closeThreshold {
                closed = true
                return .close
            }
            return .stretch(travel < 0 ? travel : Self.rubber(travel))
        case .ended:
            defer {
                total = 0
                closed = false
            }
            guard !closed else { return nil }
            return total * Self.pointsPerDelta >= Self.minimumCycle ? .cycle : .settle
        }
    }

    /// Вниз — сильное сопротивление: короткий свайп ~3.5 pt, потолок 7 (ui-inspection 3.7).
    /// Форма кривой и масштаб 10 — замера нет, оценка
    public static func rubber(_ travel: CGFloat) -> CGFloat {
        stretchCeiling * (1 - exp(-travel / 10))
    }
}
