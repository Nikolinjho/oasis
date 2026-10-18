import IslandCore

extension IslandStore {
  nonisolated static func isRestSwipeSurface(_ surface: Surface) -> Bool {
    switch surface {
    case .idle, .compact, .peek, .calendar, .calendarPeek, .hoverNudge: true
    default: false
    }
  }

  func setSoonComposing(_ composing: Bool) {
    guard attention.soonEditing != composing else { return }
    if composing {
      acquireAttention(owner: .soonComposer)
    } else if let lease = attention.leases[.soonComposer] {
      releaseAttention(lease)
    }
  }

  func pruneDeferredSoon(_ panel: SoonPanel?) {
    let active = Set(panel?.reminders.filter { $0.state != .completed }.map(\.occurrenceID) ?? [])
    attention.deferred.removeAll {
      if case .soon(let notice) = $0.alert { return !active.contains(notice.occurrenceID) }
      return false
    }
  }
}
