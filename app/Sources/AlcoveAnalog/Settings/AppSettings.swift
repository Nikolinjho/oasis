import Combine
import CoreGraphics
import Foundation
import IslandCore

/// Настройки приложения в UserDefaults. Изменение сразу уходит в onChange: AppDelegate применяет его
/// к машине острова. Выбор экрана (display) пока никуда не применяется — отдельная задача, P2.
/// ObservableObject: окно настроек держит его через @ObservedObject
@MainActor
final class AppSettings: ObservableObject {
    enum Key {
        static let expandOnHover = "expandOnHover"
        static let hoverDuration = "hoverDuration"
        static let forceSimulatedNotch = "forceSimulatedNotch"
        static let display = "display"
        static let builtInNotchWidth = "builtInNotchWidth"
        static let builtInNotchHeight = "builtInNotchHeight"
        static let playSounds = "playSounds"
    }

    var onChange: () -> Void = {}
    private let defaults: UserDefaults

    /// General → Expand on hover, по умолчанию вкл
    @Published var expandOnHover: Bool {
        didSet {
            guard oldValue != expandOnHover else { return }
            defaults.set(expandOnHover, forKey: Key.expandOnHover)
            onChange()
        }
    }
    /// General → Hover duration, 0…0.6 с, по умолчанию 0
    @Published var hoverDuration: Double {
        didSet {
            guard oldValue != hoverDuration else { return }
            defaults.set(hoverDuration, forKey: Key.hoverDuration)
            onChange()
        }
    }
    /// General → Force simulated notch: виртуальный вырез на экране без настоящего
    @Published var forceSimulatedNotch: Bool {
        didSet {
            guard oldValue != forceSimulatedNotch else { return }
            defaults.set(forceSimulatedNotch, forKey: Key.forceSimulatedNotch)
            onChange()
        }
    }
    /// General → Display on
    @Published var display: DisplayChoice {
        didSet {
            guard oldValue != display else { return }
            defaults.set(display.storageValue, forKey: Key.display)
            onChange()
        }
    }
    /// Звуки уведомлений: календарь, низкий заряд, энергосбережение. По умолчанию вкл, как у Alcove
    @Published var playSounds: Bool {
        didSet {
            guard oldValue != playSounds else { return }
            defaults.set(playSounds, forKey: Key.playSounds)
            onChange()
        }
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
            guard let newValue else {
                defaults.removeObject(forKey: Key.builtInNotchWidth)
                defaults.removeObject(forKey: Key.builtInNotchHeight)
                return
            }
            defaults.set(newValue.width, forKey: Key.builtInNotchWidth)
            defaults.set(newValue.height, forKey: Key.builtInNotchHeight)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        expandOnHover = defaults.object(forKey: Key.expandOnHover) as? Bool ?? true
        hoverDuration = defaults.object(forKey: Key.hoverDuration) as? Double ?? 0
        forceSimulatedNotch = defaults.bool(forKey: Key.forceSimulatedNotch)
        display = DisplayChoice(storageValue: defaults.string(forKey: Key.display))
        playSounds = defaults.object(forKey: Key.playSounds) as? Bool ?? true
    }

    func machineConfig(from base: IslandMachine.Config) -> IslandMachine.Config {
        base.applying(expandOnHover: expandOnHover, hoverDuration: hoverDuration)
    }
}
