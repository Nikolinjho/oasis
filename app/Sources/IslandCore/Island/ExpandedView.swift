/// Виды раскрытого острова. Свайп вниз листает их по кругу, у всех размер 345×175 (ui-inspection 3.7).
/// rawValue — ключ в UserDefaults: последний вид для Most Recent переживает перезапуск
public enum ExpandedView: String, CaseIterable, Hashable, Sendable {
  case duo, player, calendar

  public var next: ExpandedView {
    let all = Self.allCases
    return all[(all.firstIndex(of: self)! + 1) % all.count]
  }
}
