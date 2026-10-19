import IslandCore

extension IslandStore {
  /// Очередь машины и отложенные уведомления редакторов имеют один счётчик.
  /// Уже показанное событие и цель текущего сжатия в него не входят.
  @discardableResult
  func refreshPeekQueue() -> Bool {
    var excluded: Set<IslandAlert.Kind> = []
    if case .alert(let alert) = model.surface { excluded.insert(alert.kind) }
    if case .alert(let alert) = model.pending { excluded.insert(alert.kind) }
    var seen = excluded
    let alerts = (model.alertQueue + attention.deferred.map(\.alert))
      .filter { eligible($0) && seen.insert($0.kind).inserted }
      .enumerated()
      .sorted {
        if $0.element.priority == $1.element.priority { return $0.offset < $1.offset }
        return $0.element.priority > $1.element.priority
      }
      .map(\.element)
    let items = alerts.compactMap { alert in
      attentionItems.first { item in
        if case .alert(let recorded) = item.source { return recorded.kind == alert.kind }
        return false
      }
    }
    guard queuedPeeks != items else { return false }
    queuedPeeks = items
    return true
  }
}
