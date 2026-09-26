import IslandCore
import SwiftUI

struct SlotModifier: ViewModifier {
    var opacity: Double
    var blur: CGFloat
    var scaleX: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(x: scaleX, y: 1)
    }
}

extension AnyTransition {
    /// Контент не выезжает, а проявляется из размытия, сжатым по горизонтали (motion.md, «Вход и выход контента»)
    static var slot: AnyTransition {
        let identity = SlotModifier(opacity: 1, blur: 0, scaleX: 1)
        return .asymmetric(
            insertion: .modifier(
                active: SlotModifier(opacity: 0, blur: IslandTiming.slotInBlur, scaleX: 0.01),
                identity: identity
            ).animation(.easeOut(duration: IslandTiming.slotIn)),
            removal: .modifier(
                active: SlotModifier(opacity: 0, blur: IslandTiming.slotOutBlur, scaleX: IslandTiming.slotOutScaleX),
                identity: identity
            ).animation(.easeIn(duration: IslandTiming.slotOut)))
    }
}
