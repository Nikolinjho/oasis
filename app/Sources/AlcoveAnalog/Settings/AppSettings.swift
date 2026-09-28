import Combine
import CoreGraphics
import Foundation
import IslandCore

/// Настройки приложения в UserDefaults. Изменение сразу уходит в onChange: AppDelegate применяет его
/// к машине острова и к выбору экрана. ObservableObject: окно настроек держит его через @ObservedObject
@MainActor
final class AppSettings: ObservableObject {
    enum Key {
        static let expandOnHover = "expandOnHover"
        static let hoverDuration = "hoverDuration"
        static let forceSimulatedNotch = "forceSimulatedNotch"
        static let display = "display"
        static let builtInNotchWidth = "builtInNotchWidth"
        static let builtInNotchHeight = "builtInNotchHeight"
    }

    var onChange: () -> Void = {}
    private let defaults: UserDefaults

    /// General → Expand on hover, по умолчанию вкл
    @Published var expandOnHover: Bool {
        didSet { defaults.set(expandOnHover, forKey: Key.expandOnHover); onChange() }
    }
    /// General → Hover duration, 0…0.6 с, по умолчанию 0
    @Published var hoverDuration: Double {
        didSet { defaults.set(hoverDuration, forKey: Key.hoverDuration); onChange() }
    }
    /// General → Force simulated notch: виртуальный вырез на экране без настоящего
    @Published var forceSimulatedNotch: Bool {
        didSet { defaults.set(forceSimulatedNotch, forKey: Key.forceSimulatedNotch); onChange() }
    }
    /// General → Display on
    @Published var display: DisplayChoice {
        didSet { defaults.set(display.storageValue, forKey: Key.display); onChange() }
    }

    /// Последний вырез встроенного экрана: размер виртуального выреза, когда крышка закрыта.
    /// Служебное значение: onChange не зовёт
    var builtInNotch: CGSize? {
        get {
            let width = defaults.double(forKey: Key.builtInNotchWidth)
            let height = defaults.double(forKey: Key.builtInNotchHeight)
            return width > 0 && height > 0 ? CGSize(width: width, height: height) : nil
        }
        set {
            defaults.set(newValue?.width ?? 0, forKey: Key.builtInNotchWidth)
            defaults.set(newValue?.height ?? 0, forKey: Key.builtInNotchHeight)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        expandOnHover = defaults.object(forKey: Key.expandOnHover) as? Bool ?? true
        hoverDuration = defaults.object(forKey: Key.hoverDuration) as? Double ?? 0
        forceSimulatedNotch = defaults.bool(forKey: Key.forceSimulatedNotch)
        display = DisplayChoice(storageValue: defaults.string(forKey: Key.display))
    }

    func machineConfig(from base: IslandMachine.Config) -> IslandMachine.Config {
        base.applying(expandOnHover: expandOnHover, hoverDuration: hoverDuration)
    }
}
