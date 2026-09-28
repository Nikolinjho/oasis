import CoreGraphics
import Foundation

/// Двухпальцевый свайп над раскрытым островом (ui-inspection 3.7). Вход — фазы и дельты scrollWheel
/// (без инерции: у Alcove её нет), dy > 0 — пальцы вниз. Выход — что делать с островом
public struct SwipeTracker: Sendable {
    public enum Phase: Sendable {
        /// cancelled — жест прервала система (например, пальцев стало больше): вернуть, но не листать
        case began, changed, ended, cancelled
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
    /// Меньше этого вниз — не свайп, а касание. Замера нет: было 1 pt (оценка), по решению пользователя 28.09
    /// на приёмке утроено до 3 pt — 15 единиц дельты скролла
    public static let minimumCycle: CGFloat = 3
    /// Сколько дельты (по большей оси) копится в начале жеста, прежде чем решить, вертикальный он или
    /// горизонтальный. В scroll-1.log первые события — dy 1, 3, 1, 5 при dx 0–1: 4 набирается за 2–3 события
    /// (~0.8 pt острова). Замера порога у Alcove нет, оценка
    public static let axisLockDistance: CGFloat = 4

    private enum Axis { case undecided, vertical, horizontal }

    private var total: CGFloat = 0
    private var closed = false
    private var axis = Axis.undecided
    private var pendingX: CGFloat = 0

    public init() {}

    /// Горизонтальные свайпы не наши (решение пользователя 27.09): ось фиксируется один раз в начале жеста
    /// по накопленным |dx| и |dy|, и горизонтальный жест игнорируется целиком. Отбрасывать отдельные события
    /// с |dx| > |dy| хуже: у вертикального свайпа бывает дрожь по dx (в логе dy=1 dx=1), и пропуски таких
    /// событий занижали бы накопленную дельту и сдвигали порог закрытия
    public mutating func feed(_ phase: Phase, dx: CGFloat = 0, dy: CGFloat) -> Output? {
        switch phase {
        case .began:
            reset()
            return nil
        case .changed:
            guard !closed, axis != .horizontal else { return nil }
            total += dy
            if axis == .undecided {
                pendingX += dx
                guard max(abs(pendingX), abs(total)) >= Self.axisLockDistance else { return nil }
                axis = abs(pendingX) > abs(total) ? .horizontal : .vertical
                guard axis == .vertical else { return nil }
            }
            let travel = total * Self.pointsPerDelta
            if travel <= -Self.closeThreshold {
                closed = true
                return .close
            }
            return .stretch(travel < 0 ? travel : Self.rubber(travel))
        case .ended, .cancelled:
            defer { reset() }
            guard !closed, axis != .horizontal else { return nil }
            guard phase == .ended else { return .settle }
            return total * Self.pointsPerDelta >= Self.minimumCycle ? .cycle : .settle
        }
    }

    private mutating func reset() {
        total = 0
        closed = false
        axis = .undecided
        pendingX = 0
    }

    /// Вниз — сильное сопротивление: короткий свайп ~3.5 pt, потолок 7 (ui-inspection 3.7).
    /// Форма кривой и масштаб 10 — замера нет, оценка
    public static func rubber(_ travel: CGFloat) -> CGFloat {
        stretchCeiling * (1 - exp(-travel / 10))
    }
}

/// Одно событие scrollWheel, уже очищенное от инерции и мыши и приведённое к знаку «пальцы вниз — dy > 0»
public struct SwipeInput: Equatable, Sendable {
    public var phase: SwipeTracker.Phase
    public var dx: CGFloat
    public var dy: CGFloat

    public init(phase: SwipeTracker.Phase, dx: CGFloat, dy: CGFloat) {
        self.phase = phase
        self.dx = dx
        self.dy = dy
    }
}
