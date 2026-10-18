import IslandCore

extension IslandStore {
  func updateAttentionPower(state: PowerState, rules: PowerRules) {
    let lowBatteryActive =
      rules.isEnabled && rules.warnsLowBattery
      && !state.isPluggedIn && state.level <= rules.lowBatteryThreshold
    let lowPowerActive = rules.isEnabled && rules.notifiesLowPower && state.isLowPowerMode
    let chargingActive = rules.isEnabled && state.isPluggedIn
    retractPowerAttention(.lowBattery, unless: lowBatteryActive)
    retractPowerAttention(.lowPower, unless: lowPowerActive)
    retractPowerAttention(.charging, unless: chargingActive)
  }

  private func retractPowerAttention(_ kind: IslandAlert.Kind, unless active: Bool) {
    guard !active, attention.deadlines[kind] != nil, !attention.retracted.contains(kind) else { return }
    send(.alertRetracted(kind))
  }
}
