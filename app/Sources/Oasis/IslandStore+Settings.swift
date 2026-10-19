import IslandCore

extension IslandStore {
  var config: IslandMachine.Config {
    get { model.config }
    set { send(.configChanged(newValue)) }
  }

  func appearanceChanged(from previous: IslandAppearance) {
    if appearance.contrastOutline != previous.contrastOutline { onContrastOutlineChange() }
    if appearance.peekQueue != previous.peekQueue { onSurfaceChange() }
  }
}
