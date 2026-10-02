import IslandCore
import SwiftUI

struct SlotModifier: ViewModifier {
  var opacity: Double
  var blur: CGFloat

  func body(content: Content) -> some View {
    content
      .opacity(opacity)
      .blur(radius: blur)
  }
}

extension AnyTransition {
  /// Контент не выезжает и не растёт из центра, а просто проявляется из размытия и так же гаснет
  /// (motion.md, «Вход и выход контента»). Сжатие по X убрано по живой проверке: читалось как раскрытие в стороны
  static var slot: AnyTransition {
    let identity = SlotModifier(opacity: 1, blur: 0)
    return .asymmetric(
      insertion: .modifier(
        active: SlotModifier(opacity: 0, blur: IslandTiming.slotInBlur),
        identity: identity
      ).animation(.easeOut(duration: IslandTiming.slotIn)),
      removal: .modifier(
        active: SlotModifier(opacity: 0, blur: IslandTiming.slotOutBlur),
        identity: identity
      ).animation(.easeIn(duration: IslandTiming.slotOut)))
  }
}
