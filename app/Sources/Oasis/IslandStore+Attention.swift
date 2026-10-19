import Foundation
import IslandCore

extension IslandStore {
  var protectsAttention: Bool {
    attention.soonEditing || agentInputActive || !attention.leases.isEmpty || attention.restoreView != nil
      || protectsExpanded(model)
  }

  var agentsWithAttention: ClaudeAgentsPanel {
    var snapshot = agentsPanel
    snapshot.attention = attentionItems
    snapshot.showsInbox = showAttentionInbox
    return snapshot
  }

  @discardableResult
  func acquireAttention(owner: PresentationLease.Owner) -> PresentationLease {
    let lease = PresentationLease(owner: owner)
    attention.leases[owner] = lease
    return lease
  }

  func releaseAttention(_ lease: PresentationLease) {
    guard attention.leases[lease.owner] == lease else { return }
    attention.leases[lease.owner] = nil
    releaseAttentionIfPossible()
  }

  func protectsExpanded(_ state: IslandModel) -> Bool {
    state.surface == .expanded
      && (state.expandedView.isAgents
        || (state.config.dashboardNavigation
          && state.expandedView != .overview && state.expandedView != .modules))
  }

  func deferAttention(_ event: IslandEvent) -> Bool {
    switch event {
    case .alertArrived(let alert):
      return deferIncomingAlert(alert)
    case .alertRetracted(let kind):
      attention.deferred.removeAll { $0.alert.kind == kind }
      attention.retracted.insert(kind)
      deactivateAttention(kind)
    case .calendarStarted:
      return recordCalendarStart()
    default: updateAttentionContext(event)
    }
    return false
  }

  private func updateAttentionContext(_ event: IslandEvent) {
    switch event {
    case .trackChanged, .pausedTrackChanged:
      attention.musicPeekUntil = Date().addingTimeInterval(5)
    case .mediaCleared:
      attention.musicPeekUntil = nil
    case .hudChanged:
      if model.surface == .expanded && protectsAttention { attention.restoreView = model.expandedView }
    case .clickedOutside, .expandedViewRequested:
      attention.restoreView = nil
    case .soonViewAvailable(false):
      attention.deferred.removeAll { if case .soon = $0.alert { true } else { false } }
    case .fullscreenChanged(true):
      suppressFullscreenAttention()
    default: break
    }
  }

  private func deferIncomingAlert(_ alert: IslandAlert) -> Bool {
    if !attention.releasing {
      attention.retracted.remove(alert.kind)
      attention.deadlines[alert.kind] = peekDeadline(alert)
      record(alert)
    }
    guard eligible(alert) else { return true }
    guard protectsAttention else { return false }
    deferAlert(alert)
    return true
  }

  private func recordCalendarStart() -> Bool {
    guard let event = calendarEvent else { return false }
    guard min(event.start.addingTimeInterval(30), event.end) > Date() else { return true }
    attentionItems.removeAll { if case .calendar(let previous) = $0.source { previous.id == event.id } else { false } }
    appendAttention(
      .init(
        source: .calendar(event), title: event.title, detail: "Событие началось", expiresAt: event.end,
        peekEligibleUntil: min(event.start.addingTimeInterval(30), event.end)))
    return false
  }

  private func suppressFullscreenAttention() {
    var alerts = model.alertQueue + attention.deferred.map(\.alert)
    if case .alert(let alert) = model.surface { alerts.append(alert) }
    if case .alert(let alert) = model.pending { alerts.append(alert) }
    for alert in alerts where isSuppressedInFullscreen(alert) {
      attention.deadlines[alert.kind] = .distantPast
    }
    attention.deferred.removeAll { isSuppressedInFullscreen($0.alert) }
    attention.restoreView = nil
  }

  func protectQueuedAttention(_ next: inout IslandModel) {
    guard
      protectsExpanded(next) || attention.restoreView != nil || attention.soonEditing
        || agentInputActive || !attention.leases.isEmpty
    else { return }
    for alert in next.alertQueue {
      deferAlert(alert, heard: next.heardAlerts.contains(alert.kind))
      next.heardAlerts.remove(alert.kind)
    }
    next.alertQueue.removeAll()
  }

  func restoreAttentionAfterHUD(_ event: IslandEvent) -> ExpandedView? {
    guard case .timerFired(.hudHide) = event, let view = attention.restoreView else { return nil }
    attention.restoreView = nil
    return view
  }

  func releaseAttentionIfPossible() {
    guard !protectsAttention, !attention.deferred.isEmpty, !attention.releasing else { return }
    let ready = attention.deferred.filter { eligible($0.alert) }
      .enumerated().sorted {
        if $0.element.alert.priority == $1.element.alert.priority { return $0.offset < $1.offset }
        return $0.element.alert.priority > $1.element.alert.priority
      }.map(\.element)
    attention.deferred.removeAll()
    attention.releasing = true
    for value in ready {
      attention.releasingHeard = value.heard
      send(.alertArrived(value.alert))
      if value.heard, isQueuedOrPending(value.alert.kind, in: model) {
        markAlertHeard(value.alert.kind)
      }
    }
    attention.releasingHeard = false
    attention.releasing = false
  }

  func isQueuedOrPending(_ kind: IslandAlert.Kind, in state: IslandModel) -> Bool {
    if state.alertQueue.contains(where: { $0.kind == kind }) { return true }
    if case .alert(let alert) = state.pending { return alert.kind == kind }
    return false
  }

  func markPresentedRequest() {
    guard model.surface == .expanded, model.expandedView.isAgents,
      !showAttentionInbox, let id = activeAgentsPanel.selectedRequestID
    else { return }
    attention.openedRequests.insert(id)
    for index in attentionItems.indices {
      if case .alert(.claudeRequest(let requestID)) = attentionItems[index].source, requestID == id {
        attentionItems[index].unread = false
      }
    }
    attention.deferred.removeAll { $0.alert.kind == .claudeRequest(id) }
  }

  private func deferAlert(_ alert: IslandAlert, heard: Bool = false) {
    attention.deferred.removeAll { $0.alert.kind == alert.kind }
    attention.deferred.append(.init(alert: alert, heard: heard))
  }

  private func deactivateAttention(_ kind: IslandAlert.Kind) {
    for index in attentionItems.indices {
      if case .alert(let alert) = attentionItems[index].source, alert.kind == kind { attentionItems[index].active = false }
    }
  }

  func openAttention(_ id: UUID) {
    guard let index = attentionItems.firstIndex(where: { $0.id == id }) else { return }
    refreshAttention()
    let historicalRequest: Bool
    if case .alert(.claudeRequest(let requestID)) = attentionItems[index].source {
      historicalRequest = agentPanel(for: requestID).requests.contains { $0.id == requestID }
    } else {
      historicalRequest = false
    }
    guard attentionItems[index].active || historicalRequest else { return }
    attentionItems[index].unread = false
    let item = attentionItems[index]
    showAttentionInbox = false
    switch item.source {
    case .music: send(.expandedViewRequested(.player))
    case .calendar: send(.expandedViewRequested(.calendar))
    case .alert(let alert):
      openAlertAttention(alert)
    }
  }

  private func openAlertAttention(_ alert: IslandAlert) {
    switch alert {
    case .claudeRequest(let requestID):
      let provider = agentPanel(for: requestID).provider
      performAgentAction(.selectRequest(requestID), provider: provider)
      send(.expandedViewRequested(provider.view))
    case .calendarReminder: send(.expandedViewRequested(.calendar))
    case .soon(let notice):
      if let reminder = soonPanel?.reminders.first(where: { $0.occurrenceID == notice.occurrenceID }) {
        onSoonAction(.open(id: reminder.id, revision: reminder.revision))
      } else {
        onSoonAction(.showList)
      }
    case .claude: send(.expandedViewRequested(.claude))
    default: onOpenSettings()
    }
  }

  func appendAttention(_ item: IslandAttention) {
    attentionItems.insert(item, at: 0)
    if attentionItems.count > 100 { attentionItems.removeLast(attentionItems.count - 100) }
  }

  private func record(_ alert: IslandAlert) {
    attentionItems.removeAll { if case .alert(let previous) = $0.source { previous.kind == alert.kind } else { false } }
    let title: String
    let detail: String
    switch alert {
    case .claudeRequest(let id):
      let panel = agentPanel(for: id)
      let request = panel.requests.first { $0.id == id }
      title =
        request?.kind == .permission
        ? "Разрешение: \(request?.toolName ?? panel.provider.shortTitle)"
        : request?.questions.first?.text ?? "\(panel.provider.shortTitle) спрашивает"
      detail = panel.agents.first { $0.id == id.agent }?.project ?? panel.provider.title
    case .calendarReminder(let reminder):
      title = reminder.title
      detail = "Через \(reminder.minutes) мин"
    case .soon(let notice):
      title = notice.title
      detail = "Soon"
    case .charging:
      title = "Питание подключено"
      detail = "Батарея"
    case .lowBattery:
      title = "Низкий заряд"
      detail = "Батарея"
    case .lowPower:
      title = "Энергосбережение"
      detail = "Батарея"
    case .airpods(let info):
      title = info.name
      detail = "Наушники"
    case .claude:
      title = "Лимиты Claude Code"
      detail = "Подписка"
    }
    let deadline = attention.deadlines[alert.kind]
    appendAttention(.init(source: .alert(alert), title: title, detail: detail, expiresAt: deadline, peekEligibleUntil: deadline))
  }
}
