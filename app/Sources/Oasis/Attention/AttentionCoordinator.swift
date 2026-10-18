import Foundation
import IslandCore

struct DeferredAttention {
  let alert: IslandAlert
  var heard: Bool
}

struct AttentionCoordinator {
  var soonEditing: Bool { leases[.soonComposer] != nil }
  var leases: [PresentationLease.Owner: PresentationLease] = [:]
  var deferred: [DeferredAttention] = []
  var retracted: Set<IslandAlert.Kind> = []
  var deadlines: [IslandAlert.Kind: Date] = [:]
  var openedRequests: Set<ClaudeRequestID> = []
  var calendarEvents: [CalendarEvent] = []
  var knownCalendarIDs: Set<String> = []
  var musicPeekUntil: Date?
  var restoreView: ExpandedView?
  var releasing = false
  var releasingHeard = false
}
