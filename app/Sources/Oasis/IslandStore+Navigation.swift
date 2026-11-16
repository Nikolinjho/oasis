import IslandCore

extension IslandStore {
  func selectExpandedView(_ view: ExpandedView) {
    backSwipe.reset()
    if view == .soon {
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
    } else if let target = view.backTarget {
      selectExpandedView(target)
    } else {
      return false
    }
    return true
  }
}
