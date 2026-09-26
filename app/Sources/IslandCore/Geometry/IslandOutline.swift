import CoreGraphics

/// Контур острова: squircle без верхних углов плюс вогнутые плечи у края экрана.
/// Координаты сверху вниз, ширина контура = ширина острова + 2 × плечо
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

        // левое плечо: заливка между краем экрана и бортом острова под вогнутой кривой
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: shoulder, y: 0))
        path.addLine(to: CGPoint(x: shoulder, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: shoulder, y: 0))
        path.closeSubpath()

        // правое плечо зеркально
        let right = shoulder + w
        path.move(to: CGPoint(x: right + shoulder, y: 0))
        path.addLine(to: CGPoint(x: right, y: 0))
        path.addLine(to: CGPoint(x: right, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: right + shoulder, y: 0), control: CGPoint(x: right, y: 0))
        path.closeSubpath()
        return path
    }
}
