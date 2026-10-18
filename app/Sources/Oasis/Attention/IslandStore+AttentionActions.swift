import Foundation
import IslandCore

extension IslandStore {
  func performAttention(_ action: AttentionAction) {
    switch action {
    case .open(let id): openAttention(id)
    case .join(let id):
      guard let item = activeAttention(id), let event = calendarAttentionEvent(item),
        let url = MeetingLink.find(in: event)
      else { return }
      markAttentionRead(id)
      onJoin(url)
    case .completeSoon(let id):
      guard let reminder = soonAttentionReminder(id) else { return }
      markAttentionRead(id)
      onSoonAction(.complete(id: reminder.id, revision: reminder.revision))
    case .snoozeSoon(let id, let seconds):
      guard [300, 600, 900].contains(seconds), let reminder = soonAttentionReminder(id) else { return }
      markAttentionRead(id)
      onSoonAction(.snooze(id: reminder.id, revision: reminder.revision, seconds: seconds))
    }
  }

  private func activeAttention(_ id: UUID) -> IslandAttention? {
    refreshAttention()
    return attentionItems.first { $0.id == id && $0.active }
  }

  private func markAttentionRead(_ id: UUID) {
    if let index = attentionItems.firstIndex(where: { $0.id == id }) { attentionItems[index].unread = false }
  }

  private func soonAttentionReminder(_ id: UUID) -> SoonReminder? {
    guard let item = activeAttention(id), case .alert(.soon(let notice)) = item.source else { return nil }
    return soonPanel?.reminders.first { $0.occurrenceID == notice.occurrenceID && $0.state != .completed }
  }

  private func calendarAttentionEvent(_ item: IslandAttention) -> CalendarEvent? {
    let id: String
    switch item.source {
    case .calendar(let event): id = event.id
    case .alert(.calendarReminder(let reminder)): id = reminder.eventID
    default: return nil
    }
    let current = calendarEvent?.id == id ? calendarEvent : agenda.events.first { $0.id == id }
    guard let current, current.end > Date(), !dismissedEvents.contains(id), !calendarAttentionWasRemoved(id) else { return nil }
    return current
  }
}
