import CoreGraphics

/// Контур острова: squircle без верхних углов плюс вогнутые ушки у края экрана.
/// Координаты сверху вниз, ширина контура = ширина острова + 2 × ушко
public enum IslandOutline {
    public static func path(size: CGSize, bottomRadius: CGFloat, shoulder: CGFloat) -> CGPath {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        // во время пружины размер и радиус меняются вместе, радиус не должен перерасти половину стороны
        let r = max(0.5, min(bottomRadius, h / 2 - 0.5, w / 2 - 0.5))
        let svg = Squircle.svgPath(
            width: w, height: h,
            radii: .init(topLeft: 0, topRight: 0, bottomRight: r, bottomLeft: r))

        let body = CGMutablePath()
        body.addPath(SVGPath.cgPath(svg), transform: CGAffineTransform(translationX: shoulder, y: 0))
        guard shoulder > 0 else { return body }

        // ушко ниже острова не опускается: во время пружины высота и ушко растут вместе
        let earHeight = min(shoulder * EarProfile.heightRatio, h)
        let tip = EarProfile.tipHandle * shoulder
        let side = earHeight * (1 - EarProfile.sideHandle)

        let ears = CGMutablePath()
        // левое ушко: заливка между краем экрана и бортом острова над вогнутой кривой
        ears.move(to: CGPoint(x: 0, y: 0))
        ears.addLine(to: CGPoint(x: shoulder, y: 0))
        ears.addLine(to: CGPoint(x: shoulder, y: earHeight))
        ears.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: shoulder, y: side),
            control2: CGPoint(x: tip, y: 0))
        ears.closeSubpath()

        // правое ушко зеркально
        let right = shoulder + w
        ears.move(to: CGPoint(x: right + shoulder, y: 0))
        ears.addLine(to: CGPoint(x: right, y: 0))
        ears.addLine(to: CGPoint(x: right, y: earHeight))
        ears.addCurve(
            to: CGPoint(x: right + shoulder, y: 0),
            control1: CGPoint(x: right, y: side),
            control2: CGPoint(x: right + shoulder - tip, y: 0))
        ears.closeSubpath()

        // тело и ушки раньше были раздельными подпутями с общим стыком по x = shoulder / shoulder + w:
        // на дробных координатах анимации оба края сглаживались по отдельности и в стыке проступала
        // светлая нить (шов на правом ушке при live-приёмке). CGPath.union сливает их в один контур
        // без внутреннего ребра на стыке — по кадру дороже, чем addPath, но заметно не на глаз
        return body.union(ears)
    }

    /// Ширина тёмной области контура на глубине depth от края экрана: тело плюс заполненная часть ушек.
    /// Так остров меряет capture/tools/track.py: строка пикселей 2 при 2x, её середина на 1.25 pt.
    /// Модель — граница по 50% покрытию пикселя (CGPath.contains), а track.py считает тёмным пиксель
    /// < 12 из 255 (примерно 70–95% покрытия на антиалиасинге): в записи ширина читается уже,
    /// обычно на 0.6–1.5 pt — укладывается в tolerance.sizePt = 2 из capture/targets.json
    public static func rowWidth(size: CGSize, bottomRadius: CGFloat, shoulder: CGFloat, depth: CGFloat) -> CGFloat {
        let outline = path(size: size, bottomRadius: bottomRadius, shoulder: shoulder)
        let total = size.width + 2 * shoulder
        var left: CGFloat = 0
        while left < shoulder, !outline.contains(CGPoint(x: left, y: depth)) { left += 0.01 }
        var right = total
        while right > total - shoulder, !outline.contains(CGPoint(x: right, y: depth)) { right -= 0.01 }
        return right - left
    }

    /// Профиль ушка: кубическая кривая Безье от кончика у края экрана (касательная горизонтальна)
    /// к борту острова (касательная вертикальна). Совместная подгонка по видео hover-открытия Alcove
    /// 2026-09-26, профили покоя и раскрытого: максимум 0.39 px при 2x. Четверть окружности легла хуже
    /// (максимум 1.6 px). Та же форма легла на ушки компакта, peek и HUD из записей с СКО до 0.21 px
    public enum EarProfile {
        /// Высота ушка к его ширине
        public static let heightRatio: CGFloat = 0.966
        /// Горизонтальная ручка у кончика, доля ширины
        public static let tipHandle: CGFloat = 0.768
        /// Вертикальная ручка у борта, доля высоты
        public static let sideHandle: CGFloat = 0.442
    }
}
