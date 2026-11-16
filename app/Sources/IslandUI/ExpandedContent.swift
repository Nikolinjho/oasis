import IslandCore
import SwiftUI

/// Контент раскрытого по виду. Смена вида — только контент: старый гаснет в блюр, новый проявляется (ui-inspection 3.7)
struct ExpandedContent: View {
  let view: ExpandedView
  let info: NowPlayingInfo?
  let agenda: DayAgenda
  var claude: ClaudePanel?
  var codex: CodexLimitsPanel?
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
  var animatesBackNavigation = false
  var notchWidth: CGFloat = 185
  var mediaEnabled = true
  var calendarEnabled = true
  var onSelectView: (ExpandedView) -> Void = { _ in }
  var onOpenSettings: () -> Void = {}

  var body: some View {
    ZStack(alignment: .top) {
      content
        .padding(.top, navigation ? ExpandedLayout.headerHeight : 0)
      if navigation {
        ExpandedNavigation(
          view: view, width: size.width, notchWidth: notchWidth,
          onSelectView: onSelectView, onOpenSettings: onOpenSettings,
          onBack: backAction, backDestination: backTitle)
      }
    }
    .frame(width: size.width, height: size.height, alignment: .top)
  }

  private var content: some View {
    ZStack(alignment: .topLeading) {
      switch view {
      case .overview:
        OverviewView(
          info: info, agenda: agenda, claude: claude, codex: codex, soon: soon, dismissedEvents: dismissedEvents,
          appearance: appearance, mediaEnabled: mediaEnabled, calendarEnabled: calendarEnabled,
          onAction: onAction, onJoin: onJoin, onSoonAction: onSoonAction,
          onSelectView: onSelectView, notchWidth: notchWidth
        )
        .transition(contentTransition)
      case .modules:
        ModulesView(
          mediaEnabled: mediaEnabled, calendarEnabled: calendarEnabled,
          claudeAvailable: claude != nil, codexAvailable: codex != nil,
          soonAvailable: soon != nil, onSelectView: onSelectView, notchWidth: notchWidth
        )
        .transition(contentTransition)
      case .duo:
        DuoView(
          info: info, agenda: agenda, dismissedEvents: dismissedEvents, appearance: appearance, liveEvent: liveEvent,
          onJoin: onJoin, onAction: onAction
        )
        .transition(contentTransition)
      case .player:
        PlayerView(info: info, appearance: appearance, volume: volume, showsVolumeRow: showsVolumeRow, onAction: onAction)
          .frame(width: DuoLayout.size.width, height: contentHeight, alignment: .top)
          .transition(contentTransition)
      case .claude:
        if let claude {
          ClaudeLimitsView(panel: claude)
            .transition(contentTransition)
        }
      case .codex:
        if let codex {
          CodexLimitsView(panel: codex).transition(contentTransition)
        }
      case .soon:
        if let soon {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            if let selected = soon.selected {
              SoonDetailView(reminder: selected, now: context.date, onAction: onSoonAction, showsBackButton: !navigation)
            } else {
              SoonListView(panel: soon, now: context.date, onAction: onSoonAction)
            }
          }
          .id(soon.selectedID)
          .transition(contentTransition)
        }
      case .calendar:
        CalendarDayView(agenda: agenda, dismissedEvents: dismissedEvents, style: appearance.calendar, onJoin: onJoin)
          .transition(contentTransition)
      }
    }
    .frame(width: size.width, height: contentHeight, alignment: .topLeading)
  }

  private var backAction: (() -> Void)? {
    if view == .soon && soon?.selected != nil { return { onSoonAction(.showList) } }
    return nil
  }

  private var contentTransition: AnyTransition {
    animatesBackNavigation ? .swipeBack(timeScale: timeScale) : .viewSwap(timeScale: timeScale)
  }

  private var backTitle: String? {
    view == .soon && soon?.selected != nil ? "Soon" : nil
  }

  private var size: CGSize {
    if view == .overview || view == .modules {
      return DashboardLayout(
        media: mediaEnabled, calendar: calendarEnabled, claude: claude != nil, codex: codex != nil,
        soon: soon != nil, notchWidth: notchWidth
      ).size(for: view)
    }
    return ExpandedLayout.size(for: view, navigation: navigation, volumeRow: view == .player && showsVolumeRow)
  }

  private var contentHeight: CGFloat {
    size.height - (navigation ? ExpandedLayout.headerHeight : 0)
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
