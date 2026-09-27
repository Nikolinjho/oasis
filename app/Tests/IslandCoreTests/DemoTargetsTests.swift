import CoreGraphics
import Foundation
import Testing
@testable import IslandCore

/// capture/targets.json хранит ширины по строке track.py (1.25 pt ниже края), а не тела:
/// в записи меряется контур вместе с ушками. Цели выводятся из нашей геометрии
struct DemoTargetsTests {
    struct Targets: Decodable {
        struct Anchor: Decodable { let fromWidth: Double }
        struct Notch: Decodable { let width: Double; let height: Double }
        struct Segment: Decodable {
            let name: String
            let from: String
            let to: String
            let x0: Double
            let x1: Double
            let start: Double
        }
        let anchor: Anchor
        let notch: Notch
        let segments: [Segment]
    }

    static let depth: CGFloat = 1.25

    static func load() throws -> Targets {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repo.appendingPathComponent("capture/targets.json"))
        return try JSONDecoder().decode(Targets.self, from: data)
    }

    static func surface(_ name: String) -> Surface? {
        switch name {
        case "idle": .idle
        case "compact": .compact
        case "peek": .peek
        case "hover": .hover
        case "expanded": .expanded
        case "shrink": .shrink
        case "hud": .hud(.volume, level: 0.5)
        default: nil
        }
    }

    static func rowWidth(_ surface: Surface, notch: CGSize) -> Double {
        let spec = IslandGeometry.spec(for: surface, hasMedia: true, notch: notch)
        let width = IslandOutline.rowWidth(
            size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder, depth: depth)
        return (Double(width) * 10).rounded() / 10
    }

    @Test("Ширина контура: на глубине ушка — тело, у края — тело плюс часть ушек")
    func rowWidthBounds() {
        let spec = IslandGeometry.spec(for: .compact, hasMedia: true, notch: CGSize(width: 186, height: 32))
        let deep = IslandOutline.rowWidth(size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder, depth: 12)
        let edge = IslandOutline.rowWidth(size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder, depth: Self.depth)
        #expect(abs(deep - spec.size.width) < 0.05)
        #expect(edge > spec.size.width && edge < spec.size.width + 2 * spec.shoulder)
    }

    @Test("Сегменты demo-прогона: концы совпадают с контуром наших состояний на строке track.py")
    func segmentWidthsMatchGeometry() throws {
        let targets = try Self.load()
        let notch = CGSize(width: targets.notch.width, height: targets.notch.height)
        let idle = Self.rowWidth(.idle, notch: notch)
        #expect(abs(targets.anchor.fromWidth - idle) <= 0.5, "anchor.fromWidth: по геометрии \(idle)")
        for s in targets.segments {
            let from = try #require(Self.surface(s.from), "\(s.name): неизвестное from \(s.from)")
            let to = try #require(Self.surface(s.to), "\(s.name): неизвестное to \(s.to)")
            let x0 = Self.rowWidth(from, notch: notch)
            let x1 = Self.rowWidth(to, notch: notch)
            #expect(abs(s.x0 - x0) <= 0.5, "\(s.name): x0 \(s.x0), по геометрии \(x0)")
            #expect(abs(s.x1 - x1) <= 0.5, "\(s.name): x1 \(s.x1), по геометрии \(x1)")
        }
    }
}
