/// Виды раскрытого острова. Обзор и каталог открывают модули без последовательного листания.
/// rawValue — ключ в UserDefaults: последний вид для Most Recent переживает перезапуск
public enum ExpandedView: String, CaseIterable, Hashable, Sendable {
  case duo, player, calendar, claude, soon
  case overview, modules, codex

  public var backTarget: ExpandedView? {
    switch self {
    case .overview: nil
    case .modules: .overview
    default: .modules
    }
  }

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
