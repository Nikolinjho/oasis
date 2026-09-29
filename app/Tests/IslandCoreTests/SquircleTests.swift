import CoreGraphics
import Foundation
import Testing
@testable import IslandCore

struct SquircleTests {
    struct Case: Decodable {
        let w: Double
        let h: Double
        let r: Double
        let path: String
    }

    static let cases: [Case] = {
        let url = Bundle.module.url(forResource: "squircle", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
    }()

    /// Сравнивает пути по токенам: команды должны совпасть, числа — с точностью 0.001
    static func samePath(_ a: String, _ b: String) -> Bool {
        let left = a.split(separator: " "), right = b.split(separator: " ")
        guard left.count == right.count else { return false }
        return zip(left, right).allSatisfy { l, r in
            if let x = Double(l), let y = Double(r) { return abs(x - y) <= 0.001 }
            return l == r
        }
    }

    @Test("Порт даёт тот же путь, что squircle с сайта", arguments: cases)
    func matchesSite(_ c: Case) {
        let radii = Squircle.Radii(topLeft: 0, topRight: 0, bottomRight: c.r, bottomLeft: c.r)
        let ours = Squircle.svgPath(width: c.w, height: c.h, radii: radii)
        #expect(Self.samePath(ours, c.path), "\(c.w)×\(c.h) r\(c.r)\nнаш:  \(ours)\nсайт: \(c.path)")
    }

    @Test("CGPath из SVG занимает весь прямоугольник, углы снизу срезаны")
    func svgToCGPath() throws {
        let c = try #require(Self.cases.first { $0.w == 370 })
        let path = SVGPath.cgPath(c.path)
        let box = path.boundingBoxOfPath
        #expect(abs(box.minX) < 0.01 && abs(box.minY) < 0.01)
        #expect(abs(box.width - 370) < 0.01 && abs(box.height - 175) < 0.01)
        #expect(path.contains(CGPoint(x: 185, y: 170)))
        #expect(path.contains(CGPoint(x: 1, y: 1)))
        #expect(!path.contains(CGPoint(x: 1, y: 174)))
    }

    @Test("Контур с плечами шире острова на два плеча")
    func outlineWithShoulders() {
        let path = IslandOutline.path(size: CGSize(width: 261, height: 32), bottomRadius: 10, shoulder: 7)
        let box = path.boundingBoxOfPath
        #expect(abs(box.width - 275) < 0.01)
        #expect(abs(box.height - 32) < 0.01)
        // у края экрана плечо закрашено, ниже вогнутой кривой — нет
        #expect(path.contains(CGPoint(x: 6.5, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 0.5, y: 6)))
    }

    @Test("Слишком большой радиус урезается, а не роняет построение")
    func oversizedRadius() {
        let path = IslandOutline.path(size: CGSize(width: 195, height: 32), bottomRadius: 28, shoulder: 7)
        #expect(abs(path.boundingBoxOfPath.height - 32) < 0.01)
    }

    @Test("Стык тела и ушек без щели: на дробном плече по обе стороны от шва заливка есть, контур один")
    func outlineHasNoSeamAtShoulderJoin() {
        // дробное плечо — как во время пружины анимации, где и был замечен шов
        let shoulder: CGFloat = 7.37
        let width: CGFloat = 261
        let path = IslandOutline.path(size: CGSize(width: width, height: 32), bottomRadius: 10, shoulder: shoulder)
        let earHeight = shoulder * IslandOutline.EarProfile.heightRatio

        // левый стык, у самого края экрана (внутри выпуклой части ушка)
        #expect(path.contains(CGPoint(x: shoulder - 0.01, y: 1)))
        #expect(path.contains(CGPoint(x: shoulder + 0.01, y: 1)))
        // тот же стык глубже — у 90% высоты ушка, где кривая ещё держит ширину до самого борта
        let deep = earHeight * 0.9
        #expect(path.contains(CGPoint(x: shoulder - 0.01, y: deep)))
        #expect(path.contains(CGPoint(x: shoulder + 0.01, y: deep)))
        // правый стык зеркально
        let right = shoulder + width
        #expect(path.contains(CGPoint(x: right - 0.01, y: 1)))
        #expect(path.contains(CGPoint(x: right + 0.01, y: 1)))

        // тело и оба ушка сливаются в одну область: единственный контур вместо трёх раздельных подпутей
        // (старая реализация с addPath тела + двух ушек давала здесь 3 moveTo)
        var subpathStarts = 0
        path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint { subpathStarts += 1 }
        }
        #expect(subpathStarts == 1)
    }
}
