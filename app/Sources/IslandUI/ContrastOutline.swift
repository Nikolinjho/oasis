import IslandCore
import SwiftUI

/// Contrast outline Alcove (NotchContrastOutlineView): внешний кант 1.5 pt, белый ≈10%, вокруг раскрытого
/// над тёмным фоном (ui-inspection §1.2, осмотр 03.10). Штрих 3 pt по контуру, внутреннюю половину
/// закрывает заливка формы поверх: так кант ложится над тенью раскрытого, а не под ней
struct ContrastOutline: View {
  let spec: IslandShapeSpec

  /// Белый 10%: замер по кадрам над чёрной подложкой
  static let color = Color.white.opacity(0.10)
  /// Снаружи видна половина: 1.5 pt
  static let lineWidth: CGFloat = 3

  var body: some View {
    ZStack(alignment: .top) {
      IslandShape(spec: spec).stroke(Self.color, lineWidth: Self.lineWidth)
      IslandShape(spec: spec).fill(IslandPalette.background)
    }
  }

  /// У Alcove кант только у раскрытого: в покое и у компакта его нет, над светлым фоном тоже
  static func isVisible(surface: Surface, enabled: Bool, backdropDark: Bool) -> Bool {
    surface == .expanded && enabled && backdropDark
  }
}
