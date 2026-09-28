/// Battery → Hide label, Hide percentage (ui-inspection 1.3)
public struct BatteryAlertStyle: Equatable, Sendable {
    public var hidesLabel: Bool
    /// Только у Low Battery: у Charging и Low Power процента нет (решение 28.09)
    public var hidesPercentage: Bool

    public init(hidesLabel: Bool = false, hidesPercentage: Bool = false) {
        self.hidesLabel = hidesLabel
        self.hidesPercentage = hidesPercentage
    }
}

/// Как остров рисует свои поверхности: настройки страниц, которые меняют вид, а не поведение.
/// Поведение живёт в IslandMachine.Config. Store держит значение и отдаёт его в IslandView и геометрию
public struct IslandAppearance: Equatable, Sendable {
    public var battery = BatteryAlertStyle()

    public init() {}

    public static let `default` = IslandAppearance()
}
