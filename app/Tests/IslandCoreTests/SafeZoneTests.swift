import CoreGraphics
import Testing

@testable import IslandCore

/// Окно под блюр и безопасная зона hover раскрытого (ui-inspection §1.2, замер Alcove 03.10)
struct SafeZoneTests {
  @Test("Окно вмещает раскрытый с безопасной зоной блюра и спадом блюра 80 pt")
  func windowFitsBlur() {
    let expanded = GeometryTests.rects(.expanded).island
    let window = IslandGeometry.windowFrame(for: GeometryTests.mbp16)
    // вниз блюр сходит на нет за 80 pt: под раскрытым 175 места хватает
    #expect(expanded.minY - window.minY >= 80)
    #expect(window.contains(IslandGeometry.safeZone(around: expanded, blur: true)))
  }

  @Test("Безопасная зона вокруг раскрытого: без блюра 15 в стороны и 32 вниз, с блюром 35 и 35 (замер Alcove 03.10)")
  func safeZoneRect() {
    let rect = CGRect(x: 100, y: 500, width: 300, height: 175)
    #expect(IslandGeometry.safeZone(around: rect, blur: false) == CGRect(x: 85, y: 468, width: 330, height: 207))
    #expect(IslandGeometry.safeZone(around: rect, blur: true) == CGRect(x: 65, y: 465, width: 370, height: 210))
  }

  @Test("Раскрытый держится, пока курсор в безопасной зоне, и отпускает за ней")
  func expandedSafeZoneKeepsPointer() {
    let compact = GeometryTests.rects(.compact)
    let expanded = GeometryTests.rects(.expanded)
    func inside(_ point: CGPoint, _ zone: IslandGeometry.SafeZone?) -> Bool {
      IslandGeometry.pointerInside(
        point, body: expanded.body, island: expanded.island, openedFrom: compact.body, expandedSafeZone: zone)
    }
    let below30 = CGPoint(x: expanded.island.midX, y: expanded.island.minY - 30)
    let below34 = CGPoint(x: expanded.island.midX, y: expanded.island.minY - 34)
    #expect(inside(below30, .plain))
    #expect(!inside(below34, .plain))
    #expect(inside(below34, .blurred))
    #expect(!inside(CGPoint(x: expanded.island.midX, y: expanded.island.minY - 36), .blurred))
    let side14 = CGPoint(x: expanded.island.minX - 14, y: 1100)
    let side16 = CGPoint(x: expanded.island.minX - 16, y: 1100)
    #expect(inside(side14, .plain))
    #expect(!inside(side16, .plain))
    #expect(inside(side16, .blurred))
    // без зоны (компакт, hover) — как раньше, только форма
    #expect(!inside(below30, nil))
  }

  @Test("Безопасная зона не открывает hover: вход по-прежнему только над телом")
  func safeZoneDoesNotOpen() {
    let idle = GeometryTests.rects(.idle, media: false)
    let beside = CGPoint(x: idle.body.minX - 10, y: 1107)
    #expect(
      !IslandGeometry.pointerInside(beside, body: idle.body, island: idle.island, openedFrom: nil, expandedSafeZone: .blurred))
  }
}
