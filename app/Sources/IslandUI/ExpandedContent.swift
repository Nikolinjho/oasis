import IslandCore
import SwiftUI

/// Контент раскрытого по виду. Смена вида — только контент: старый гаснет в блюр, новый проявляется (ui-inspection 3.7)
struct ExpandedContent: View {
    let view: ExpandedView
    let info: NowPlayingInfo?
    let agenda: DayAgenda
    let onAction: (PlayerAction) -> Void
    let onJoin: (URL) -> Void
    var timeScale: Double = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch view {
            case .duo:
                DuoView(info: info, agenda: agenda, onJoin: onJoin, onAction: onAction)
                    .transition(.viewSwap(timeScale: timeScale))
            case .player:
                PlayerView(info: info, onAction: onAction)
                    .frame(width: DuoLayout.size.width, height: DuoLayout.size.height, alignment: .top)
                    .transition(.viewSwap(timeScale: timeScale))
            case .calendar:
                CalendarDayView(agenda: agenda, onJoin: onJoin)
                    .transition(.viewSwap(timeScale: timeScale))
            }
        }
        .frame(width: DuoLayout.size.width, height: DuoLayout.size.height, alignment: .topLeading)
    }
}

extension AnyTransition {
    /// Смена вида раскрытого: уход в блюр ~0.1 с, проявление из блюра ~0.13 с после него (ui-inspection 3.7).
    /// Длительности растянуты timeScale, как у playerEntrance. Размытие 10 — как у входа контента, оценка
    static func viewSwap(timeScale: Double) -> AnyTransition {
        let identity = SlotModifier(opacity: 1, blur: 0)
        return .asymmetric(
            insertion: .modifier(active: SlotModifier(opacity: 0, blur: IslandTiming.slotInBlur), identity: identity)
                .animation(.easeOut(duration: 0.13 * timeScale).delay(0.1 * timeScale)),
            removal: .modifier(active: SlotModifier(opacity: 0, blur: IslandTiming.slotInBlur), identity: identity)
                .animation(.easeIn(duration: 0.1 * timeScale)))
    }
}
