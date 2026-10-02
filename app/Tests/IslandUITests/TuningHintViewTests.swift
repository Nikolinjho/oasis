import IslandCore
import SwiftUI
import Testing

@testable import IslandUI

/// Подложка подгонки выреза (Task 17t)
struct TuningHintViewTests {
  @MainActor
  @Test("Снимки width- и height-подсказки")
  func snapshots() throws {
    let notch = CGSize(width: 185, height: 32)
    let cases: [(name: String, hint: TuningHint, size: CGSize)] = [
      ("tuning-width", .width(-1), CGSize(width: notch.width, height: IslandGeometry.tuningWidthHeight)),
      (
        "tuning-height", .height(0),
        CGSize(
          width: IslandGeometry.notchRelativeWidth(IslandGeometry.compact.width, notch: notch.width),
          height: IslandGeometry.tuningHeightBase)
      ),
    ]
    for (name, hint, size) in cases {
      let view = ZStack(alignment: .top) {
        IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: IslandGeometry.bottomRadius(forHeight: size.height)), shoulder: 0)
          .fill(IslandPalette.tuning)
        TuningHintView(hint: hint, notchWidth: notch.width)
      }
      try Snapshot.write(view, size: size, name: name)
    }
  }
}
