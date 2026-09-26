import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct IslandShapeTests {
    static let compact = IslandShapeSpec(size: CGSize(width: 261, height: 32), bottomRadius: 10)

    @Test("Форма по центру рамки, прижата к верху, с плечами")
    func centeredAtTop() {
        let box = IslandShape(spec: Self.compact)
            .path(in: CGRect(x: 0, y: 0, width: 440, height: 210))
            .cgPath.boundingBoxOfPath
        #expect(abs(box.minX - 82.5) < 0.01)
        #expect(abs(box.minY) < 0.01)
        #expect(abs(box.width - 275) < 0.01)
        #expect(abs(box.height - 32) < 0.01)
    }

    @Test("animatableData хранит размер и радиус")
    func animatableRoundTrip() {
        var shape = IslandShape(spec: Self.compact)
        let data = shape.animatableData
        shape.animatableData = data
        #expect(shape.size == CGSize(width: 261, height: 32))
        #expect(shape.bottomRadius == 10)
    }

    @MainActor
    @Test("Снимок формы компакта")
    func snapshot() throws {
        let view = IslandShape(spec: Self.compact).fill(IslandPalette.background)
        #expect(try Snapshot.write(view, size: CGSize(width: 440, height: 210), name: "shape-compact") == CGSize(width: 880, height: 420))
    }
}
