import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct IslandShapeTests {
    static let compact = IslandShapeSpec(size: CGSize(width: 261, height: 32), bottomRadius: 10, shoulder: 8)
    static let expanded = IslandShapeSpec(size: CGSize(width: 370, height: 175), bottomRadius: 28, shoulder: 29.5)

    @Test("Форма по центру рамки, прижата к верху, с ушками")
    func centeredAtTop() {
        let box = IslandShape(spec: Self.compact)
            .path(in: CGRect(x: 0, y: 0, width: 460, height: 210))
            .cgPath.boundingBoxOfPath
        #expect(abs(box.minX - 91.5) < 0.01)
        #expect(abs(box.minY) < 0.01)
        #expect(abs(box.width - 277) < 0.01)
        #expect(abs(box.height - 32) < 0.01)
    }

    @Test("Без ушек форма равна телу острова: по ней обрезается контент")
    func withoutShoulders() {
        let box = IslandShape(spec: Self.expanded, shoulder: 0)
            .path(in: CGRect(x: 0, y: 0, width: 460, height: 210))
            .cgPath.boundingBoxOfPath
        #expect(abs(box.width - 370) < 0.01)
    }

    @Test("animatableData хранит размер, радиус и ушко")
    func animatableRoundTrip() {
        var shape = IslandShape(spec: Self.compact)
        let data = shape.animatableData
        shape.animatableData = data
        #expect(shape.size == CGSize(width: 261, height: 32))
        #expect(shape.bottomRadius == 10)
        #expect(shape.shoulder == 8)
    }

    @Test("Ушко анимируется вместе с размером: середина пути между компактом и раскрытым")
    func shoulderInterpolates() {
        var shape = IslandShape(spec: Self.compact)
        var data = IslandShape(spec: Self.expanded).animatableData
        data -= shape.animatableData
        data.scale(by: 0.5)
        shape.animatableData += data
        #expect(abs(shape.shoulder - 18.75) < 0.001)
        #expect(abs(shape.size.width - 315.5) < 0.001)
    }

    @MainActor
    @Test("Снимок формы компакта")
    func snapshot() throws {
        let view = IslandShape(spec: Self.compact).fill(IslandPalette.background)
        #expect(try Snapshot.write(view, size: CGSize(width: 460, height: 210), name: "shape-compact") == CGSize(width: 920, height: 420))
    }

    @MainActor
    @Test("Снимок формы раскрытого плеера: ушки для сверки с ref-ears.png")
    func snapshotExpanded() throws {
        let view = IslandShape(spec: Self.expanded).fill(IslandPalette.background)
        try Snapshot.write(view, size: IslandGeometry.windowSize, name: "shape-expanded")
    }
}
