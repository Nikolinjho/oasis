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
        static let hideMenuBarIcon = "hideMenuBarIcon"
        static let notchWidthOffset = "notchWidthOffset"
        static let notchHeightOffset = "notchHeightOffset"
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
    /// General → Hide menu bar icon (ключ Alcove settings.general.hideMenuBarIcon). Меню остаётся по правому
    /// клику на острове: иконку в menu bar часто закрывает компакт
    @Published var hideMenuBarIcon: Bool {
        didSet {
            guard oldValue != hideMenuBarIcon else { return }
            defaults.set(hideMenuBarIcon, forKey: Key.hideMenuBarIcon)
            onChange()
        }
    }

    /// General → Tuning → Notch width, pt, −2…2
    @Published var notchWidthOffset: Double {
        didSet {
            guard oldValue != notchWidthOffset else { return }
            defaults.set(notchWidthOffset, forKey: Key.notchWidthOffset)
            onChange()
        }
    }
    /// General → Tuning → Notch height, pt, −2…2
    @Published var notchHeightOffset: Double {
        didSet {
            guard oldValue != notchHeightOffset else { return }
            defaults.set(notchHeightOffset, forKey: Key.notchHeightOffset)
            onChange()
        }
    }

    /// Сдвиг выреза для окна острова. Значения из UserDefaults могли прийти руками: зажимаем в −2…2
    var notchTuning: NotchTuning {
        NotchTuning(width: min(max(notchWidthOffset, -2), 2), height: min(max(notchHeightOffset, -2), 2))
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
        hideMenuBarIcon = defaults.bool(forKey: Key.hideMenuBarIcon)
        notchWidthOffset = defaults.double(forKey: Key.notchWidthOffset)
        notchHeightOffset = defaults.double(forKey: Key.notchHeightOffset)
    }

    func machineConfig(from base: IslandMachine.Config) -> IslandMachine.Config {
        base.applying(expandOnHover: expandOnHover, hoverDuration: hoverDuration)
    }
}
