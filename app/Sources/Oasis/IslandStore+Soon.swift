import IslandCore

struct SoonCompositionState {
  var isComposing = false
  var deferred: [IslandAlert] = []
}

extension IslandStore {
  /// Покой, по которому свайп убирает и возвращает активность
  nonisolated static func isRestSwipeSurface(_ surface: Surface) -> Bool {
    switch surface {
    case .idle, .compact, .peek, .calendar, .calendarPeek, .hoverNudge: true
    default: false
    }
  }

  /// Редактор остаётся открытым при уведомлениях. HUD продолжает проходить в машину сразу.
  func setSoonComposing(_ composing: Bool) {
    guard soonComposition.isComposing != composing else { return }
    soonComposition.isComposing = composing
    guard !composing else { return }
    let deferred = soonComposition.deferred
    soonComposition.deferred.removeAll()
    for alert in deferred { send(.alertArrived(alert)) }
  }

  func pruneDeferredSoon(_ panel: SoonPanel?) {
    let active = Set(panel?.reminders.filter { $0.state != .completed }.map(\.occurrenceID) ?? [])
    soonComposition.deferred.removeAll {
      if case .soon(let notice) = $0 { return !active.contains(notice.occurrenceID) }
      return false
    }
  }

  func deferSoonComposition(_ event: IslandEvent) -> Bool {
    switch event {
    case .alertArrived(let alert) where soonComposition.isComposing:
      guard !suppressed(alert, fullscreen: model.isFullscreen, hideSoon: model.config.hideSoonPeekInFullscreen) else { return true }
      soonComposition.deferred.removeAll { $0.kind == alert.kind }
      soonComposition.deferred.append(alert)
      return true
    case .alertRetracted(let kind):
      soonComposition.deferred.removeAll { $0.kind == kind }
    case .soonViewAvailable(false):
      soonComposition.deferred.removeAll { if case .soon = $0 { true } else { false } }
    case .fullscreenChanged(let fullscreen):
      soonComposition.deferred.removeAll {
        suppressed($0, fullscreen: fullscreen, hideSoon: model.config.hideSoonPeekInFullscreen)
      }
    case .configChanged(let config):
      soonComposition.deferred.removeAll {
        suppressed($0, fullscreen: model.isFullscreen, hideSoon: config.hideSoonPeekInFullscreen)
      }
    default: break
    }
    return false
  }

  private func suppressed(_ alert: IslandAlert, fullscreen: Bool, hideSoon: Bool) -> Bool {
    guard fullscreen else { return false }
    switch alert {
    case .soon: return hideSoon
    case .claude(let notice): return !notice.urgent
    default: return false
    }
  }
}
