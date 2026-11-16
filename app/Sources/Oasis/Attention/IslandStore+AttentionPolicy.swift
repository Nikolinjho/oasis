import Foundation
import IslandCore

extension IslandStore {
  func peekDeadline(_ alert: IslandAlert, now: Date = Date()) -> Date {
    switch alert {
    case .calendarReminder(let reminder):
      return eventForAttention(reminder.eventID)?.start ?? now.addingTimeInterval(Double(reminder.minutes) * 60)
    case .soon(let notice):
      return soonPanel?.reminders.first { $0.occurrenceID == notice.occurrenceID }?.dueAt.addingTimeInterval(60) ?? now
    default:
      return now.addingTimeInterval(60)
    }
  }

  func eligible(_ alert: IslandAlert, now: Date = Date(), forPeek: Bool = true) -> Bool {
    guard !attention.retracted.contains(alert.kind) else { return false }
    if forPeek {
      if model.isFullscreen && isSuppressedInFullscreen(alert) { return false }
      if let deadline = attention.deadlines[alert.kind], deadline <= now {
        return false
      }
    }
    switch alert {
    case .calendarReminder(let reminder):
      return calendarReminderEligible(reminder, now: now)
    case .soon(let notice):
      return soonPanel?.reminders.contains {
        $0.occurrenceID == notice.occurrenceID && $0.state != .completed
          && (!forPeek || $0.dueAt.addingTimeInterval(60) > now)
      } == true
    default:
      return attention.deadlines[alert.kind].map { $0 > now } ?? true
    }
  }

  private func calendarReminderEligible(_ reminder: CalendarReminder, now: Date) -> Bool {
    guard !dismissedEvents.contains(reminder.eventID) else { return false }
    if calendarAttentionWasRemoved(reminder.eventID) { return false }
    if let event = eventForAttention(reminder.eventID) { return event.start > now }
    return attention.deadlines[.calendarReminder(eventID: reminder.eventID)].map { $0 > now } ?? false
  }

  func isSuppressedInFullscreen(_ alert: IslandAlert) -> Bool {
    switch alert {
    case .soon: model.config.hideSoonPeekInFullscreen
    case .claude(let notice): !notice.urgent
    default: false
    }
  }

  func refreshAttention(now: Date = Date()) {
    for index in attentionItems.indices {
      switch attentionItems[index].source {
      case .alert(let alert):
        attentionItems[index].active = eligible(alert, now: now, forPeek: false)
      case .calendar(let event):
        attentionItems[index].active =
          event.end > now && !dismissedEvents.contains(event.id)
          && !calendarAttentionWasRemoved(event.id)
      case .music:
        attentionItems[index].active = false
      }
    }
  }

  func prepareAttention(_ next: inout IslandModel) -> [IslandEffect] {
    refreshAttention()
    next.alertQueue.removeAll { !eligible($0) }
    next.heardAlerts = next.heardAlerts.filter { kind in
      isQueuedOrPending(kind, in: next)
    }
    if attention.restoreView != nil { protectQueuedAttention(&next) }
    if case .alert(let alert) = next.pending, !eligible(alert) {
      next.pending = next.alertQueue.isEmpty ? next.base : .alert(next.alertQueue.removeFirst())
    }
    if case .alert(let alert) = next.surface, !eligible(alert) {
      return IslandMachine.reduce(&next, .alertRetracted(alert.kind))
    }
    return expireActivityPeek(&next)
  }

  private func expireActivityPeek(_ next: inout IslandModel, now: Date = Date()) -> [IslandEffect] {
    if next.surface == .peek, let expiry = attention.musicPeekUntil, expiry <= now {
      next.surface = next.base
      return [.cancel(.peekEnd)]
    }
    if next.surface == .calendarPeek, let event = calendarEvent,
      min(event.start.addingTimeInterval(30), event.end) <= now
    {
      next.surface = next.base
      return [.cancel(.calendarPeekEnd)]
    }
    return []
  }

  func updateAttentionCalendar(_ events: [CalendarEvent]) {
    attention.calendarEvents = events
    attention.knownCalendarIDs.formUnion(events.map(\.id))
  }

  func calendarAttentionWasRemoved(_ id: String) -> Bool {
    attention.knownCalendarIDs.contains(id) && !attention.calendarEvents.contains { $0.id == id }
  }

  private func eventForAttention(_ id: String) -> CalendarEvent? {
    if let event = attention.calendarEvents.first(where: { $0.id == id }) { return event }
    if calendarEvent?.id == id { return calendarEvent }
    return agenda.events.first { $0.id == id }
  }
}
