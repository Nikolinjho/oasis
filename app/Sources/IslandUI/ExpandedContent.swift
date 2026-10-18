import IslandCore
import SwiftUI

/// Контент раскрытого по виду. Смена вида — только контент: старый гаснет в блюр, новый проявляется (ui-inspection 3.7)
struct ExpandedContent: View {
  let view: ExpandedView
  var agents = ClaudeAgentsPanel()
  var onAgentsAction: (ClaudeAgentsAction) -> Void = { _ in }
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
  var navigation = false
  var notchWidth: CGFloat = 185
  var mediaEnabled = true
  var calendarEnabled = true
  var onSelectView: (ExpandedView) -> Void = { _ in }
  var onOpenSettings: () -> Void = {}

  var body: some View {
    ZStack(alignment: .top) {
      content
        .padding(.top, (navigation || view == .agents || view == .inbox) ? ExpandedLayout.headerHeight : 0)
      if navigation || view == .agents || view == .inbox {
        ExpandedNavigation(
          view: view, width: size.width, notchWidth: notchWidth,
          onSelectView: onSelectView, onOpenSettings: onOpenSettings, waitingCount: agents.waitingCount,
          attentionCount: agents.attention.filter { $0.active && $0.unread }.count,
          onFilterWaiting: { onAgentsAction(.filterWaiting(true)) })
      }
    }
    .frame(width: size.width, height: size.height, alignment: .top)
  }

  private var content: some View {
    ZStack(alignment: .topLeading) {
      switch view {
      case .overview:
        OverviewView(
          info: info, agenda: agenda, claude: claude, agents: agents, soon: soon, dismissedEvents: dismissedEvents,
          appearance: appearance, mediaEnabled: mediaEnabled, calendarEnabled: calendarEnabled,
          onAction: onAction, onJoin: onJoin, onSoonAction: onSoonAction,
          onSelectView: onSelectView, onOpenSettings: onOpenSettings
        )
        .transition(.viewSwap(timeScale: timeScale))
      case .modules:
        ModulesView(
          mediaEnabled: mediaEnabled, calendarEnabled: calendarEnabled,
          claudeAvailable: claude != nil, soonAvailable: soon != nil, onSelectView: onSelectView
        )
        .transition(.viewSwap(timeScale: timeScale))
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
      case .inbox:
        AttentionInboxView(panel: agents, onAction: onAgentsAction)
      case .agents:
        ClaudeAgentsView(
          panel: agents, onAction: onAgentsAction, onOpenSettings: onOpenSettings, context: liveEvent, music: info,
          soonCount: soon?.reminders.filter { $0.state != .completed }.count ?? 0, onJoin: onJoin)
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
    .frame(width: size.width, height: contentHeight, alignment: .topLeading)
  }

  private var size: CGSize {
    view == .agents
      ? CGSize(width: agents.width, height: agents.height)
      : ExpandedLayout.size(for: view, navigation: navigation, volumeRow: view == .player && showsVolumeRow)
  }

  private var contentHeight: CGFloat {
    size.height - ((navigation || view == .agents || view == .inbox) ? ExpandedLayout.headerHeight : 0)
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
