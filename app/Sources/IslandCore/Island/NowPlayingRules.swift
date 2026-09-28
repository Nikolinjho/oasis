/// Now Playing (ui-inspection 1.8): что машина делает с музыкой в покое
public struct NowPlayingRules: Equatable, Sendable {
    /// Главный тумблер: компакт и peek музыки. Duo и плеер в раскрытом остаются
    public var isEnabled = true
    /// Idle duration, 0…10 с: сколько компакт держится после паузы. Дальше — форма выреза, как у Alcove
    /// в покое «всё на паузе» (ui-inspection 3.1). Что именно считает Alcove, не проверяли: допущение плана P2
    public var idleDelay: Duration = .seconds(3)
    /// Extension → Quick Peek: peek с названием на смене трека
    public var quickPeek = true
    /// Extension → When media changes: peek и при возобновлении после паузы. Допущение плана P2
    public var peeksOnPlayback = true
    /// Extension → Peek duration, 1…6 с
    public var peekDuration: Duration = IslandTiming.quickPeek
    /// Hide while source app is active
    public var hidesWhileSourceActive = false

    public init() {}
}
