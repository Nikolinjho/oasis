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
        #expect(IslandGeometry.windowFrame(for: Self.mbp16) == CGRect(x: 634, y: 907, width: 460, height: 210))
    }

    @Test("Окно вмещает пик перелёта раскрытия из покоя вместе с ушками")
    func windowFitsOvershoot() throws {
        let notch = Self.mbp16.notchSize
        for transition in [IslandTransition.expand, .hoverExpand] {
            let overshoot = try #require(IslandMotion.spring(for: transition)).overshoot
            let expanded = IslandGeometry.expanded
            let body = expanded.width + overshoot * (expanded.width - notch.width)
            let shoulder = IslandGeometry.Shoulder.expanded * (1 + overshoot)
            #expect(IslandGeometry.windowSize.width >= body + 2 * shoulder, "\(transition)")
            #expect(IslandGeometry.windowSize.height >= expanded.height + overshoot * (expanded.height - notch.height))
        }
    }

    @Test("Экранный прямоугольник острова включает ушки своего состояния")
    func islandScreenRect() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let spec = IslandGeometry.spec(for: .compact, hasMedia: true, notch: Self.mbp16.notchSize)
        #expect(IslandGeometry.islandScreenRect(spec, windowFrame: window) == CGRect(x: 727.5, y: 1085, width: 273, height: 32))
        let expanded = IslandGeometry.spec(for: .expanded, hasMedia: true, notch: Self.mbp16.notchSize)
        #expect(IslandGeometry.islandScreenRect(expanded, windowFrame: window).width == 404)
    }

    @Test("Ушки по состояниям: в покое нет, в раскрытом по кадру пользователя, hover — оценка")
    func shoulders() {
        let notch = Self.mbp16.notchSize
        func shoulder(_ surface: Surface, media: Bool = true) -> CGFloat {
            IslandGeometry.spec(for: surface, hasMedia: media, notch: notch).shoulder
        }
        #expect(shoulder(.idle) == 0)
        #expect(shoulder(.compact) == 8)
        #expect(shoulder(.peek) == 9)
        #expect(shoulder(.hud(.volume, level: 0.5)) == 8)
        #expect(shoulder(.shrink) == 8)
        #expect(shoulder(.expanded) == 29.5)
        #expect(shoulder(.hover, media: true) == 12.6)
        #expect(shoulder(.hover, media: false) == 15.4)
    }

    @Test("Профиль ушка раскрытого плеера совпадает с кадром Alcove в пределах 1 pt")
    func earProfileMatchesReference() {
        // ref-ears.png, 2x: строгая граница чёрного по строкам, тело острова с x = 421 px
        let reference: [(y: CGFloat, x: CGFloat)] = [
            (0, 370), (4, 385), (8, 393), (12, 399), (16, 403), (20, 407), (24, 410), (28, 412),
            (32, 414), (36, 416), (40, 417), (44, 418), (48, 419), (52, 420), (56, 421), (64, 421), (72, 421),
        ]
        let spec = IslandGeometry.spec(for: .expanded, hasMedia: true, notch: Self.mbp16.notchSize)
        let path = IslandOutline.path(size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder)
        for row in reference {
            // центр строки пикселей в пунктах
            let y = (row.y + 0.5) / 2
            var x: CGFloat = 0
            while x < spec.shoulder, !path.contains(CGPoint(x: x, y: y)) { x += 0.05 }
            let measured = spec.shoulder - x
            let expected = (421 - row.x) / 2
            #expect(abs(measured - expected) <= 1, "y = \(row.y) px: \(measured) против \(expected)")
        }
    }

    @Test("Зона hover в покое: вырез ±30 pt по бокам и 6 pt вниз")
    func hoverZone() {
        #expect(IslandGeometry.hoverZone(for: Self.mbp16) == CGRect(x: 741, y: 1079, width: 246, height: 38))
    }

    @Test("Hover держится над формой, из которой открылся: у края компакта нет мигания")
    func hoverHysteresis() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let notch = CGSize(width: 186, height: 32)
        let compact = IslandGeometry.islandScreenRect(
            IslandGeometry.spec(for: .compact, hasMedia: true, notch: notch), windowFrame: window)
        let hover = IslandGeometry.islandScreenRect(
            IslandGeometry.spec(for: .hover, hasMedia: true, notch: notch), windowFrame: window)
        // край компакта: внутри компакта, но левее узкой hover-формы
        let edge = CGPoint(x: compact.minX + 3, y: window.maxY - 10)
        #expect(!hover.contains(edge))

        // вход: курсор над компактом
        #expect(IslandGeometry.pointerInside(edge, island: compact, hoverZone: nil, openedFrom: nil))
        // hover открыт: форма сузилась, но курсор над компактом, из которого hover открылся
        #expect(IslandGeometry.pointerInside(edge, island: hover, hoverZone: nil, openedFrom: compact))
        // без запомненной формы курсор оказался бы снаружи и hover бы закрылся
        #expect(!IslandGeometry.pointerInside(edge, island: hover, hoverZone: nil, openedFrom: nil))
        // уход за пределы обеих форм закрывает hover
        let away = CGPoint(x: compact.minX - 5, y: window.maxY - 10)
        #expect(!IslandGeometry.pointerInside(away, island: hover, hoverZone: nil, openedFrom: compact))
    }

    @Test("В покое вход в hover засчитывается по зоне вокруг выреза")
    func hoverZoneEntry() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let idle = IslandGeometry.islandScreenRect(
            IslandGeometry.spec(for: .idle, hasMedia: false, notch: CGSize(width: 186, height: 32)), windowFrame: window)
        let zone = IslandGeometry.hoverZone(for: Self.mbp16)
        let beside = CGPoint(x: Self.mbp16.notchRect.minX - 20, y: window.maxY - 10)
        #expect(!idle.contains(beside))
        #expect(IslandGeometry.pointerInside(beside, island: idle, hoverZone: zone, openedFrom: nil))
    }

    @Test("Курсор, упёртый в верх экрана над вырезом, считается внутри")
    func pointerAtTopEdge() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let notch = CGSize(width: 186, height: 32)
        let top = CGPoint(x: Self.mbp16.notchRect.midX, y: Self.mbp16.screenFrame.maxY)
        let idle = IslandGeometry.islandScreenRect(
            IslandGeometry.spec(for: .idle, hasMedia: false, notch: notch), windowFrame: window)
        let expanded = IslandGeometry.islandScreenRect(
            IslandGeometry.spec(for: .expanded, hasMedia: true, notch: notch), windowFrame: window)
        // NSRect.contains не включает maxY: без поправки курсор у края экрана был бы снаружи
        #expect(!idle.contains(top))
        #expect(IslandGeometry.pointerInside(top, island: idle, hoverZone: nil, openedFrom: nil))
        #expect(IslandGeometry.pointerInside(top, island: idle, hoverZone: IslandGeometry.hoverZone(for: Self.mbp16), openedFrom: nil))
        #expect(IslandGeometry.pointerInside(top, island: expanded, hoverZone: nil, openedFrom: idle))
        // выше края экрана курсор не бывает, но и там остров не растягивается дальше 1 pt
        #expect(!IslandGeometry.pointerInside(CGPoint(x: top.x, y: top.y + 2), island: idle, hoverZone: nil, openedFrom: nil))
    }
}
