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

        let path = CGMutablePath()
        path.addPath(SVGPath.cgPath(svg), transform: CGAffineTransform(translationX: shoulder, y: 0))
        guard shoulder > 0 else { return path }

        // ушко ниже острова не опускается: во время пружины высота и ушко растут вместе
        let earHeight = min(shoulder * EarProfile.heightRatio, h)
        let tip = EarProfile.tipHandle * shoulder
        let side = earHeight * (1 - EarProfile.sideHandle)

        // левое ушко: заливка между краем экрана и бортом острова над вогнутой кривой
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: shoulder, y: 0))
        path.addLine(to: CGPoint(x: shoulder, y: earHeight))
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: shoulder, y: side),
            control2: CGPoint(x: tip, y: 0))
        path.closeSubpath()

        // правое ушко зеркально
        let right = shoulder + w
        path.move(to: CGPoint(x: right + shoulder, y: 0))
        path.addLine(to: CGPoint(x: right, y: 0))
        path.addLine(to: CGPoint(x: right, y: earHeight))
        path.addCurve(
            to: CGPoint(x: right + shoulder, y: 0),
            control1: CGPoint(x: right, y: side),
            control2: CGPoint(x: right + shoulder - tip, y: 0))
        path.closeSubpath()
        return path
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
