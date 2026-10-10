import IslandCore
import SwiftUI

/// Контент раскрытого по виду. Смена вида — только контент: старый гаснет в блюр, новый проявляется (ui-inspection 3.7)
struct ExpandedContent: View {
  let view: ExpandedView
  let info: NowPlayingInfo?
  let agenda: DayAgenda
  var claude: ClaudePanel?
  var soon: SoonPanel?
  var onSoonAction: (SoonAction) -> Void = { _ in }
  var dismissedEvents: Set<String> = []
  var appearance = IslandAppearance.default
  var liveEvent: CalendarEvent?
  var volume: Double = 0
  var showsVolumeRow = false
  let onAction: (PlayerAction) -> Void
  let onJoin: (URL) -> Void
  var timeScale: Double = 1

  var body: some View {
    ZStack(alignment: .topLeading) {
      switch view {
      case .duo:
        DuoView(
          info: info, agenda: agenda, dismissedEvents: dismissedEvents, appearance: appearance, liveEvent: liveEvent,
          onJoin: onJoin, onAction: onAction
        )
        .transition(.viewSwap(timeScale: timeScale))
      case .player:
        PlayerView(info: info, appearance: appearance, volume: volume, showsVolumeRow: showsVolumeRow, onAction: onAction)
          .frame(width: DuoLayout.size.width, height: contentHeight, alignment: .top)
          .transition(.viewSwap(timeScale: timeScale))
      case .claude:
        if let claude {
          ClaudeLimitsView(panel: claude)
            .transition(.viewSwap(timeScale: timeScale))
        }
      case .soon:
        if let soon {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            if let selected = soon.selected {
              SoonDetailView(reminder: selected, now: context.date, onAction: onSoonAction)
            } else {
              SoonListView(panel: soon, now: context.date, onAction: onSoonAction)
            }
          }
          .transition(.viewSwap(timeScale: timeScale))
        }
      case .calendar:
        CalendarDayView(agenda: agenda, dismissedEvents: dismissedEvents, style: appearance.calendar, onJoin: onJoin)
          .transition(.viewSwap(timeScale: timeScale))
      }
    }
    .frame(width: DuoLayout.size.width, height: contentHeight, alignment: .topLeading)
  }

  /// Duo и календарь — фиксированные 175 (DuoLayout.size), как раньше. Плеер со строкой громкости выше
  /// на IslandGeometry.volumeRowHeight: высота контента совпадает с IslandGeometry.spec(volumeRow: true),
  /// а не остаётся 175 в расчёте, что лишнее просто не обрежется вышестоящим clipShape
  private var contentHeight: CGFloat {
    guard view == .player, showsVolumeRow else { return DuoLayout.size.height }
    return DuoLayout.size.height + IslandGeometry.volumeRowHeight
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
