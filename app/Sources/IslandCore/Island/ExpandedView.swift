/// Виды раскрытого острова. Свайп вниз листает их по кругу, у всех размер 345×175 (ui-inspection 3.7)
public enum ExpandedView: CaseIterable, Hashable, Sendable {
    case duo, player, calendar

    public var next: ExpandedView {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}
