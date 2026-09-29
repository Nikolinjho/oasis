/// Idle Activity (General, ui-inspection 1.2): плитки None / Playing / Calendar / Duo. По ключам Alcove
/// (idleActivity.expandedActivity.*) они выбирают вид раскрытого, а не покой (решение 28.09)
public enum IdleActivity: String, CaseIterable, Sendable {
    case none, playing, calendar, duo
}

public struct ExpandedRules: Equatable, Sendable {
    public var idleActivity = IdleActivity.duo
    /// Most Recent: открывать последний просмотренный вид, плитки не действуют
    public var mostRecent = false
    /// Force enable activity: Playing открывается и без музыки. Выкл — без музыки Duo. Календарю не нужно:
    /// пустой день он рисует сам. Допущение плана P2
    public var forceEnable = true

    public init() {}

    /// Вид при раскрытии. nil — None: остров не раскрывается
    public func openingView(last: ExpandedView, hasMedia: Bool) -> ExpandedView? {
        if mostRecent { return last }
        switch idleActivity {
        case .none: return nil
        case .duo: return .duo
        case .calendar: return .calendar
        case .playing: return hasMedia || forceEnable ? .player : .duo
        }
    }
}
