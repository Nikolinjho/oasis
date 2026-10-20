import IslandCore

extension IslandStore {
  func selectExpandedView(_ view: ExpandedView) {
    backSwipe.reset()
    if view == .inbox, model.expandedView.isAgents {
      performAgentAction(.openInbox, provider: activeAgentsPanel.provider)
    } else if view.isAgents {
      performAgentAction(.openPanel, provider: view == .codexAgents ? .codex : .claude)
    } else if view == .soon {
      onSoonAction(.showList)
    } else {
      send(.expandedViewRequested(view))
    }
  }

  @discardableResult
  func navigateBack() -> Bool {
    guard model.surface == .expanded else { return false }
    let view = model.expandedView
    if view == .soon, soonPanel?.selected != nil {
      onSoonAction(.showList)
    } else if view == .inbox {
      selectExpandedView(attentionInboxProvider.view)
    } else if let target = view.backTarget {
      selectExpandedView(target)
    } else {
      return false
    }
    return true
  }
}
