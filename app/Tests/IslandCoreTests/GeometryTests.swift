import CoreGraphics
import Testing
@testable import IslandCore

struct GeometryTests {
    /// MacBook Pro 16": экран 1728×1117 pt, вырез 186×32
    static let mbp16 = NotchMetrics(
        screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        auxiliaryTopLeft: CGRect(x: 0, y: 1085, width: 771, height: 32),
        auxiliaryTopRight: CGRect(x: 957, y: 1085, width: 771, height: 32),
        safeAreaTop: 32)!

    @Test("Вырез — промежуток между auxiliary-областями")
    func notchFromAuxiliaryAreas() {
        #expect(Self.mbp16.notchSize == CGSize(width: 186, height: 32))
        #expect(Self.mbp16.notchRect == CGRect(x: 771, y: 1085, width: 186, height: 32))
    }

    @Test("Без auxiliary-областей выреза нет")
    func noNotch() {
        let metrics = NotchMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            auxiliaryTopLeft: nil, auxiliaryTopRight: nil, safeAreaTop: 0)
        #expect(metrics == nil)
    }

    @Test("Размеры тела острова совпадают с замерами Alcove без ушек")
    func surfaceSizes() {
        let notch = Self.mbp16.notchSize
        func size(_ surface: Surface, media: Bool = true) -> CGSize {
            IslandGeometry.spec(for: surface, hasMedia: media, notch: notch).size
        }
        #expect(size(.idle) == notch)
        #expect(size(.compact) == CGSize(width: 257, height: 32))
        #expect(size(.peek) == CGSize(width: 276, height: 51))
        #expect(size(.hover, media: true) == CGSize(width: 190, height: 73))
        #expect(size(.hover, media: false) == CGSize(width: 203, height: 90))
        #expect(size(.expanded) == CGSize(width: 345, height: 175))
        #expect(size(.hud(.volume, level: 0.5)) == CGSize(width: 367, height: 32))
        #expect(size(.shrink) == CGSize(width: 188, height: 32))
    }

    @Test("Радиус нижних углов по видео Alcove: 10.5 в покое, 35 в раскрытом, линейно по высоте")
    func radiusFromVideo() {
        #expect(abs(IslandGeometry.bottomRadius(forHeight: 32) - 10.5) < 1e-9)
        #expect(abs(IslandGeometry.bottomRadius(forHeight: 175) - 35) < 1e-9)
        #expect(abs(IslandGeometry.bottomRadius(forHeight: 103.5) - 22.75) < 1e-9)
    }

    @Test("Радиус нижних углов меньше половины высоты")
    func radiusFitsHeight() {
        let surfaces: [Surface] = [.idle, .compact, .peek, .hover, .expanded, .shrink, .hud(.brightness, level: 1)]
        for surface in surfaces {
            let spec = IslandGeometry.spec(for: surface, hasMedia: true, notch: Self.mbp16.notchSize)
            #expect(spec.bottomRadius < spec.size.height / 2, "\(surface)")
        }
    }

    @Test("Окно прижато к верху экрана по центру выреза")
    func windowFrame() {
        #expect(IslandGeometry.windowFrame(for: Self.mbp16) == CGRect(x: 644, y: 907, width: 440, height: 210))
    }

    @Test("Окно вмещает пик перелёта раскрытия из покоя вместе с ушками")
    func windowFitsOvershoot() throws {
        let notch = Self.mbp16.notchSize
        for transition in [IslandTransition.expand, .hoverExpand] {
            let overshoot = try #require(IslandMotion.spring(for: transition)).overshoot
            let expanded = IslandGeometry.expanded
            let body = expanded.width + overshoot * (expanded.width - notch.width)
            let shoulder = IslandGeometry.Shoulder.expanded
                + overshoot * (IslandGeometry.Shoulder.expanded - IslandGeometry.Shoulder.idle)
            #expect(IslandGeometry.windowSize.width >= body + 2 * shoulder, "\(transition)")
            #expect(IslandGeometry.windowSize.height >= expanded.height + overshoot * (expanded.height - notch.height))
        }
    }

    @Test("Экранный прямоугольник острова включает ушки своего состояния")
    func islandScreenRect() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let spec = IslandGeometry.spec(for: .compact, hasMedia: true, notch: Self.mbp16.notchSize)
        let rect = IslandGeometry.islandScreenRect(spec, windowFrame: window)
        #expect(abs(rect.minX - 726.7) < 1e-9 && abs(rect.width - 274.6) < 1e-9)
        #expect(rect.maxY == 1117 && rect.height == 32)
        let expanded = IslandGeometry.spec(for: .expanded, hasMedia: true, notch: Self.mbp16.notchSize)
        #expect(abs(IslandGeometry.islandScreenRect(expanded, windowFrame: window).width - 381.6) < 1e-9)
    }

    @Test("Ушки по состояниям: покой и раскрытый по видео, компакт, peek и HUD по записям, hover — оценка")
    func shoulders() {
        let notch = Self.mbp16.notchSize
        func shoulder(_ surface: Surface, media: Bool = true) -> CGFloat {
            IslandGeometry.spec(for: surface, hasMedia: media, notch: notch).shoulder
        }
        #expect(shoulder(.idle) == 5.15)
        #expect(shoulder(.compact) == 8.8)
        #expect(shoulder(.peek) == 9.8)
        #expect(shoulder(.hud(.volume, level: 0.5)) == 8.7)
        #expect(shoulder(.shrink) == 8.8)
        #expect(shoulder(.expanded) == 18.3)
        #expect(shoulder(.hover, media: true) == 11.3)
        #expect(shoulder(.hover, media: false) == 12.5)
    }

    /// Расстояние от борта до края ушка по строкам пикселей (2x) на центре строки
    static func earProfile(_ surface: Surface, rows: [CGFloat]) -> [CGFloat] {
        let spec = IslandGeometry.spec(for: surface, hasMedia: true, notch: mbp16.notchSize)
        let path = IslandOutline.path(size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder)
        return rows.map { row in
            let y = (row + 0.5) / 2
            var x: CGFloat = 0
            while x < spec.shoulder, !path.contains(CGPoint(x: x, y: y)) { x += 0.01 }
            return spec.shoulder - x
        }
    }

    @Test("Профиль ушка раскрытого и покоя совпадает с видео Alcove в пределах 0.5 pt")
    func earProfileMatchesVideo() {
        // видео hover-открытия 2026-09-26: расстояние от борта, px при 2x, по строкам сверху
        let open: [(row: CGFloat, px: CGFloat)] = [
            (0, 29.4), (2, 20.9), (4, 16.8), (6, 13.4), (8, 10.9), (10, 9.0), (12, 7.3), (14, 5.8), (16, 4.6),
            (18, 3.5), (20, 2.7), (22, 2.0), (24, 1.4), (26, 0.9), (28, 0.7), (30, 0.3), (32, 0), (40, 0),
        ]
        let rest: [(row: CGFloat, px: CGFloat)] = [(0, 6.7), (1, 4.4), (2, 3.0), (3, 2.1), (4, 1.0), (6, 0.3), (7, 0), (12, 0)]
        for (surface, reference) in [(Surface.expanded, open), (.idle, rest)] {
            let measured = Self.earProfile(surface, rows: reference.map(\.row))
            for (row, value) in zip(reference, measured) {
                #expect(abs(value - row.px / 2) <= 0.5, "\(surface) строка \(row.row): \(value) против \(row.px / 2)")
            }
        }
    }

    static func rects(_ surface: Surface, media: Bool = true) -> (body: CGRect, island: CGRect) {
        let window = IslandGeometry.windowFrame(for: mbp16)
        let spec = IslandGeometry.spec(for: surface, hasMedia: media, notch: mbp16.notchSize)
        return (IslandGeometry.bodyScreenRect(spec, windowFrame: window), IslandGeometry.islandScreenRect(spec, windowFrame: window))
    }

    @Test("Тело острова в покое — ровно вырез, без ушек")
    func idleBodyIsNotch() {
        #expect(Self.rects(.idle, media: false).body == Self.mbp16.notchRect)
    }

    @Test("Hover держится над формой, из которой открылся: у края компакта нет мигания")
    func hoverHysteresis() {
        let compact = Self.rects(.compact)
        let hover = Self.rects(.hover)
        // край компакта: внутри тела компакта, но левее узкой hover-формы
        let edge = CGPoint(x: compact.body.minX + 3, y: 1107)
        #expect(!hover.island.contains(edge))

        // вход: курсор над телом компакта
        #expect(IslandGeometry.pointerInside(edge, body: compact.body, island: compact.island, openedFrom: nil))
        // hover открыт: форма сузилась, но курсор над компактом, из которого hover открылся
        #expect(IslandGeometry.pointerInside(edge, body: hover.body, island: hover.island, openedFrom: compact.body))
        // без запомненной формы курсор оказался бы снаружи и hover бы закрылся
        #expect(!IslandGeometry.pointerInside(edge, body: hover.body, island: hover.island, openedFrom: nil))
        // уход за пределы обеих форм закрывает hover
        let away = CGPoint(x: compact.island.minX - 5, y: 1107)
        #expect(!IslandGeometry.pointerInside(away, body: hover.body, island: hover.island, openedFrom: compact.body))
    }

    @Test("Вход в hover только над телом: рядом с вырезом и над ушком не срабатывает")
    func entryOnlyOverBody() {
        let idle = Self.rects(.idle, media: false)
        let beside = CGPoint(x: Self.mbp16.notchRect.minX - 20, y: 1107)
        #expect(!IslandGeometry.pointerInside(beside, body: idle.body, island: idle.island, openedFrom: nil))
        let onEar = CGPoint(x: idle.body.minX - 1, y: 1116.5)
        #expect(idle.island.contains(onEar))
        #expect(!IslandGeometry.pointerInside(onEar, body: idle.body, island: idle.island, openedFrom: nil))
        let below = CGPoint(x: Self.mbp16.notchRect.midX, y: Self.mbp16.notchRect.minY - 2)
        #expect(!IslandGeometry.pointerInside(below, body: idle.body, island: idle.island, openedFrom: nil))
        let over = CGPoint(x: Self.mbp16.notchRect.midX, y: 1100)
        #expect(IslandGeometry.pointerInside(over, body: idle.body, island: idle.island, openedFrom: nil))
    }

    @Test("Курсор, упёртый в верх экрана над вырезом, считается внутри")
    func pointerAtTopEdge() {
        let top = CGPoint(x: Self.mbp16.notchRect.midX, y: Self.mbp16.screenFrame.maxY)
        let idle = Self.rects(.idle, media: false)
        let expanded = Self.rects(.expanded)
        // NSRect.contains не включает maxY: без поправки курсор у края экрана был бы снаружи
        #expect(!idle.body.contains(top))
        #expect(IslandGeometry.pointerInside(top, body: idle.body, island: idle.island, openedFrom: nil))
        #expect(IslandGeometry.pointerInside(top, body: expanded.body, island: expanded.island, openedFrom: idle.body))
        // выше края экрана курсор не бывает, но и там остров не растягивается дальше 1 pt
        let above = CGPoint(x: top.x, y: top.y + 2)
        #expect(!IslandGeometry.pointerInside(above, body: idle.body, island: idle.island, openedFrom: nil))
    }
}
