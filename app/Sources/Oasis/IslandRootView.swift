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
      codex: store.codexWithAttention, onCodexAction: store.onCodexAction, inboxProvider: store.attentionInboxProvider,
      soon: store.soonPanel,
      dismissedEvents: store.dismissedEvents,
      calendarEvent: store.calendarEvent,
      dragBlurred: store.dragBlurred,
      backSwipeOffset: store.backSwipe.offset, animatesBackNavigation: store.backSwipe.navigating,
      appearance: store.appearance,
      backdropDark: store.backdropDark,
      volume: store.volumeLevel,
      onClick: { store.send(.clicked) },
      onAction: { store.onAction($0) },
      onJoin: { store.onJoin($0) },
      onSoonAction: { store.onSoonAction($0) },
      mediaEnabled: store.mediaEnabled, calendarEnabled: store.calendarFilter.isEnabled,
      onSelectView: store.selectExpandedView,
      onOpenSettings: {
        store.performAgentAction(.close, provider: store.activeAgentsPanel.provider)
        store.onOpenSettings()
      },
      contentSpec: store.contentSpec,
      queuedPeeks: store.queuedPeeks)
  }
}
