/// Виды раскрытого острова. Свайп вниз листает их по кругу, у всех размер 345×175 (ui-inspection 3.7).
/// rawValue — ключ в UserDefaults: последний вид для Most Recent переживает перезапуск
public enum ExpandedView: String, CaseIterable, Hashable, Sendable {
  case duo, player, calendar, claude, soon

  public var next: ExpandedView {
    let all = Self.allCases
    return all[(all.firstIndex(of: self)! + 1) % all.count]
  }

  /// Следующий вид, пропуская недоступные. Duo всегда остаётся в цикле.
  public func next(skipping hidden: Set<ExpandedView>) -> ExpandedView {
    var view = next
    while hidden.contains(view), view != .duo, view != self { view = view.next }
    return view
  }
}
