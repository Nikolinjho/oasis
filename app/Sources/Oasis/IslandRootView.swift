import IslandCore
import IslandUI
import SwiftUI

struct IslandRootView: View {
  let store: IslandStore

  var body: some View {
    IslandView(
      model: store.model,
      spec: store.spec,
      notchWidth: store.notch.width,
      nowPlaying: store.nowPlaying,
      agenda: store.agenda,
      claude: store.claudePanel,
      agents: store.agentsWithAttention, onAgentsAction: store.onAgentsAction,
      soon: store.soonPanel,
      dismissedEvents: store.dismissedEvents,
      calendarEvent: store.calendarEvent,
      dragBlurred: store.dragBlurred,
      appearance: store.appearance,
      backdropDark: store.backdropDark,
      volume: store.volumeLevel,
      onClick: { store.send(.clicked) },
      onAction: { store.onAction($0) },
      onJoin: { store.onJoin($0) },
      onSoonAction: { store.onSoonAction($0) },
      mediaEnabled: store.mediaEnabled, calendarEnabled: store.calendarFilter.isEnabled,
      onSelectView: { view in
        if view == .agents {
          store.onAgentsAction(.openPanel)
          return
        }
        if view == .soon { store.onSoonAction(.showList) } else { store.send(.expandedViewRequested(view)) }
      },
      onOpenSettings: {
        store.onAgentsAction(.close)
        store.onOpenSettings()
      })
  }
}
