import CoreGraphics

public struct IslandShapeSpec: Equatable, Sendable {
    public var size: CGSize
    public var bottomRadius: CGFloat
    /// Ширина ушка с каждой стороны. Зависит от состояния и анимируется вместе с размером
    public var shoulder: CGFloat

    public init(size: CGSize, bottomRadius: CGFloat, shoulder: CGFloat = 0) {
        self.size = size
        self.bottomRadius = bottomRadius
        self.shoulder = shoulder
    }
}

/// Размеры тела острова без ушек (MacBook Pro 16"). Ширины в capture/analysis/README.md сняты трекером
/// по строке 1 pt ниже края экрана и включают часть ушек: компакт 263.5 (в README 261), peek 284 (283),
/// раскрытый 370, HUD 374, сжатие 195. Здесь ширина тела по кадрам, где борт отделён от ушка
public enum IslandGeometry {
    /// rec2/player-sheet.png, 4-й ряд: тело 514 px
    public static let compact = CGSize(width: 257, height: 32)
    /// rec2/player-sheet.png, 5-й ряд: тело 552 px
    public static let peek = CGSize(width: 276, height: 51)
    /// Тело не мерили: ширина из README (строка 1 pt, с ушками), оценка
    public static let hoverWithMedia = CGSize(width: 190, height: 73)
    /// Тело не мерили: ширина из README (строка 1 pt, с ушками), оценка
    public static let hoverEmpty = CGSize(width: 203, height: 90)
    /// Видео hover-открытия Alcove 2026-09-26: 345.1×175.0 (пик 359.3×187.7); rec2 и кадр пользователя — те же 345
    public static let expanded = CGSize(width: 345, height: 175)
    /// states/t69.4.png (запись №1): тело 732.5 px, в строке 1 pt ушки добавляют по 3.6 pt с каждой стороны
    public static let hud = CGSize(width: 367, height: 32)
    /// Ширина, до которой остров сжимается при смене активности. Трекер дал 195 по строке 1 pt;
    /// минус те же 7 pt ушек, что у компакта и HUD той же высоты. Выведено, а не измерено напрямую
    public static let shrinkWidth: CGFloat = 188

    /// Ушки (вогнутые плечи) по бокам: форма перетекает в menu bar. Ширина геометрическая,
    /// от кончика кривой у края экрана до борта острова; видимая ширина у края чуть меньше (≈0.88),
    /// потому что кончик тоньше пикселя. Форма одна на все состояния (IslandOutline.EarProfile),
    /// масштабируется шириной. Замеры: кадры Alcove, остров 0, фон по половине яркости, 1 pt = 2 px
    public enum Shoulder {
        /// В покое остров совпадает с вырезом, ушек нет: трекер по строке 1 pt ниже края
        /// дал ровно 186 = ширина выреза (capture/analysis/track-2026-09-26.json)
        public static let idle: CGFloat = 0
        /// rec2/player-sheet.png, 4-й ряд: видимая 6.3 pt, эталонная форма легла с СКО 0.18 px
        public static let compact: CGFloat = 8
        /// rec2/player-sheet.png, 5-й ряд: видимая 7.1 pt, СКО 0.15 px
        public static let peek: CGFloat = 9
        /// states/t69.4.png (запись №1): видимая 6.3 pt, СКО 0.18 px
        public static let hud: CGFloat = 8
        /// Замера нет: как у компакта и HUD той же высоты 32
        public static let shrink: CGFloat = 8
        /// Раскрытый плеер по кадру пользователя ref-ears.png (масштаб принят 2x): видимая 25.8 pt.
        /// Alcove 1.7.7 в записях давал меньше (rec2: 20 pt), берём кадр пользователя
        public static let expanded: CGFloat = 29.5

        /// Hover не мерили: оценка линейно по высоте между peek (51 → 9) и раскрытым (175 → 29.5)
        public static func estimated(forHeight height: CGFloat) -> CGFloat {
            let (h0, s0) = (peekHeight, peek)
            let (h1, s1) = (IslandGeometry.expanded.height, expanded)
            return ((s0 + (height - h0) * (s1 - s0) / (h1 - h0)) * 10).rounded() / 10
        }

        private static let peekHeight = IslandGeometry.peek.height
    }

    /// Окно под самое большое состояние с перелётом и ушками. Раскрытие из покоя (пружина 175/16,
    /// перелёт 9.2%): тело 370 → пик 386.9, ушко 29.5 → 32.2, всего 451.3 × 188.1. Запас до 460
    public static let windowSize = CGSize(width: 460, height: 210)

    public static func spec(for surface: Surface, hasMedia: Bool, notch: CGSize) -> IslandShapeSpec {
        let size: CGSize = switch surface {
        case .idle: notch
        case .compact: compact
        case .peek: peek
        case .hover: hasMedia ? hoverWithMedia : hoverEmpty
        case .expanded: expanded
        case .shrink: CGSize(width: shrinkWidth, height: notch.height)
        case .hud: hud
        }
        let shoulder: CGFloat = switch surface {
        case .idle: Shoulder.idle
        case .compact: Shoulder.compact
        case .peek: Shoulder.peek
        case .hover: Shoulder.estimated(forHeight: size.height)
        case .expanded: Shoulder.expanded
        case .shrink: Shoulder.shrink
        case .hud: Shoulder.hud
        }
        return IslandShapeSpec(size: size, bottomRadius: bottomRadius(forHeight: size.height), shoulder: shoulder)
    }

    /// Радиус нижних углов (squircle-порт с сайта). Замер видео hover-открытия Alcove 2026-09-26,
    /// подгонка контура по коду сайта: 10.5 pt в покое (высота 32), 35 pt в раскрытом (175), на пике 36.
    /// Между ними линейно по высоте. Меньше половины высоты при любой высоте от 32
    public static func bottomRadius(forHeight height: CGFloat) -> CGFloat {
        let (h0, r0): (CGFloat, CGFloat) = (32, 10.5)
        let (h1, r1): (CGFloat, CGFloat) = (175, 35)
        return r0 + (height - h0) * (r1 - r0) / (h1 - h0)
    }

    /// Рамка окна: верх у края экрана, по центру выреза
    public static func windowFrame(for metrics: NotchMetrics) -> CGRect {
        CGRect(
            x: metrics.screenFrame.midX - windowSize.width / 2,
            y: metrics.screenFrame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height)
    }

    /// Контур острова вместе с ушками в координатах экрана
    public static func islandScreenRect(_ spec: IslandShapeSpec, windowFrame: CGRect) -> CGRect {
        let width = spec.size.width + 2 * spec.shoulder
        return CGRect(
            x: windowFrame.midX - width / 2,
            y: windowFrame.maxY - spec.size.height,
            width: width,
            height: spec.size.height)
    }

    /// Зона hover в покое: вырез ±30 pt по бокам и 6 pt вниз
    /// Замера нет, оценка на глаз, уточняется при сверке в задаче 16
    public static func hoverZone(for metrics: NotchMetrics) -> CGRect {
        let notch = metrics.notchRect
        return CGRect(x: notch.minX - 30, y: notch.minY - 6, width: notch.width + 60, height: notch.height + 6)
    }

    /// Курсор над островом с гистерезисом. Пока hover открыт (openedFrom не nil), он держится над
    /// объединением текущей формы и формы, из которой открылся: hover уже компакта, и без этого
    /// у краёв компакта hover открывался и закрывался на каждом движении мыши
    public static func pointerInside(_ point: CGPoint, island: CGRect, hoverZone: CGRect?, openedFrom: CGRect?) -> Bool {
        let area = openedFrom.map(island.union) ?? hoverZone.map(island.union) ?? island
        return reachingScreenTop(area).contains(point)
    }

    /// Прямоугольник, растянутый вверх на 1 pt. NSRect.contains не включает maxY, а курсор,
    /// упёртый в верх экрана, стоит ровно на maxY экрана: без растяжки он был бы снаружи острова
    public static func reachingScreenTop(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + 1)
    }
}
