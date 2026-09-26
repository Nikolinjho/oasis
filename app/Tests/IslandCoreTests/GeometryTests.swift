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

    @Test("Размеры состояний совпадают с замерами Alcove")
    func surfaceSizes() {
        let notch = Self.mbp16.notchSize
        func size(_ surface: Surface, media: Bool = true) -> CGSize {
            IslandGeometry.spec(for: surface, hasMedia: media, notch: notch).size
        }
        #expect(size(.idle) == notch)
        #expect(size(.compact) == CGSize(width: 261, height: 32))
        #expect(size(.peek) == CGSize(width: 283, height: 51))
        #expect(size(.hover, media: true) == CGSize(width: 190, height: 73))
        #expect(size(.hover, media: false) == CGSize(width: 203, height: 90))
        #expect(size(.expanded) == CGSize(width: 370, height: 175))
        #expect(size(.hud(.volume, level: 0.5)) == CGSize(width: 374, height: 32))
        #expect(size(.shrink) == CGSize(width: 195, height: 32))
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

    @Test("Окно вмещает пик перелёта раскрытия с плечами")
    func windowFitsOvershoot() {
        #expect(IslandGeometry.windowSize.width >= 382 + 2 * IslandGeometry.shoulder)
        #expect(IslandGeometry.windowSize.height >= 187.5)
    }

    @Test("Экранный прямоугольник острова включает плечи")
    func islandScreenRect() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let spec = IslandGeometry.spec(for: .compact, hasMedia: true, notch: Self.mbp16.notchSize)
        #expect(IslandGeometry.islandScreenRect(spec, windowFrame: window) == CGRect(x: 726.5, y: 1085, width: 275, height: 32))
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
}
