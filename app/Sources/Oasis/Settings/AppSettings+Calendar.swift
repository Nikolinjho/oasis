import Combine
import Foundation
import IslandCore

/// Страница Calendar (ui-inspection 1.9). Отдельный объект: AppSettings за лимитом длины.
/// Изменение зовёт onChange — AppSettings пробрасывает его в свой onChange, AppDelegate применяет на лету
@MainActor
final class CalendarSettings: ObservableObject {
  enum Key {
    static let enabled = "calendarEnabled"
    static let leadMinutes = "calendarLeadMinutes"
    static let sound = "calendarSound"
    static let hourlyChime = "calendarHourlyChime"
    static let useColor = "calendarUseColor"
    static let disableDuringEvents = "calendarDisableDuringEvents"
    static let eventIndicators = "calendarEventIndicators"
    static let monthView = "calendarMonthView"
    static let quickPeek = "calendarQuickPeek"
    static let peekBeforeStart = "calendarPeekBeforeStart"
    static let peekOnStart = "calendarPeekOnStart"
    static let peekDuration = "calendarPeekDuration"
    static let coloredIndicator = "calendarColoredIndicator"
    static let excluded = "calendarExcluded"
    static let modes = "calendarModes"
  }

  var onChange: () -> Void = {}
  private let defaults: UserDefaults

  /// Главный тумблер: выкл — нет компакта, peek, напоминаний и событий в раскрытом
  @Published var isEnabled: Bool { didSet { save(oldValue, isEnabled, Key.enabled) } }
  /// Time before event, 5…30 мин, шаг 5
  @Published var leadMinutes: Double { didSet { save(oldValue, leadMinutes, Key.leadMinutes) } }
  /// Play sound on calendar event
  @Published var sound: Bool { didSet { save(oldValue, sound, Key.sound) } }
  @Published var hourlyChime: Bool { didSet { save(oldValue, hourlyChime, Key.hourlyChime) } }
  /// Use calendar color: иконка и кольцо компакта в цвете календаря
  @Published var useColor: Bool { didSet { save(oldValue, useColor, Key.useColor) } }
  @Published var disableDuringEvents: Bool { didSet { save(oldValue, disableDuringEvents, Key.disableDuringEvents) } }
  @Published var eventIndicators: Bool { didSet { save(oldValue, eventIndicators, Key.eventIndicators) } }
  /// Always show month view
  @Published var monthView: Bool { didSet { save(oldValue, monthView, Key.monthView) } }
  // Extension
  @Published var quickPeek: Bool { didSet { save(oldValue, quickPeek, Key.quickPeek) } }
  /// Before event starts: peek в начале окна (T − Time before event)
  @Published var peekBeforeStart: Bool { didSet { save(oldValue, peekBeforeStart, Key.peekBeforeStart) } }
  /// When event is starting: peek на старте
  @Published var peekOnStart: Bool { didSet { save(oldValue, peekOnStart, Key.peekOnStart) } }
  /// Peek duration, 1…6 с
  @Published var peekDuration: Double { didSet { save(oldValue, peekDuration, Key.peekDuration) } }
  @Published var coloredIndicator: Bool { didSet { save(oldValue, coloredIndicator, Key.coloredIndicator) } }
  /// Выключенные чекбоксом календари, по calendarIdentifier
  @Published var excluded: Set<String> {
    didSet {
      guard oldValue != excluded else { return }
      defaults.set(excluded.sorted(), forKey: Key.excluded)
      onChange()
    }
  }
  /// Режимы календарей. Both не хранится: новый и сброшенный календарь — Both
  @Published var modes: [String: CalendarDisplayMode] {
    didSet {
      guard oldValue != modes else { return }
      defaults.set(modes.mapValues(\.rawValue), forKey: Key.modes)
      onChange()
    }
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    isEnabled = Self.read(defaults, Key.enabled, true)
    leadMinutes = Self.read(defaults, Key.leadMinutes, 15.0)
    sound = Self.read(defaults, Key.sound, true)
    hourlyChime = Self.read(defaults, Key.hourlyChime, false)
    useColor = Self.read(defaults, Key.useColor, false)
    disableDuringEvents = Self.read(defaults, Key.disableDuringEvents, false)
    eventIndicators = Self.read(defaults, Key.eventIndicators, false)
    monthView = Self.read(defaults, Key.monthView, false)
    quickPeek = Self.read(defaults, Key.quickPeek, true)
    peekBeforeStart = Self.read(defaults, Key.peekBeforeStart, false)
    peekOnStart = Self.read(defaults, Key.peekOnStart, true)
    peekDuration = Self.read(defaults, Key.peekDuration, 4.0)
    coloredIndicator = Self.read(defaults, Key.coloredIndicator, true)
    excluded = Set(defaults.stringArray(forKey: Key.excluded) ?? [])
    let stored = defaults.dictionary(forKey: Key.modes) as? [String: String] ?? [:]
    modes = stored.compactMapValues(CalendarDisplayMode.init(rawValue:)).filter { $0.value != .both }
  }

  /// Time before event в секундах. UserDefaults могли поправить руками: зажимаем в 5…30 мин
  var lead: TimeInterval { min(max(leadMinutes, 5), 30) * 60 }
  /// Peek duration, зажатая в 1…6 с
  var peekSeconds: Double { min(max(peekDuration, 1), 6) }

  var filter: CalendarFilter {
    CalendarFilter(isEnabled: isEnabled, excluded: excluded, modes: modes)
  }

  /// Peek на старте, его длительность и звук: машина острова (IslandMachine.Config.calendar)
  var rules: CalendarRules {
    var rules = CalendarRules()
    rules.peeksOnStart = quickPeek && peekOnStart
    rules.peekDuration = CalendarRules.peekDuration(seconds: peekSeconds)
    rules.sound = sound
    return rules
  }

  /// Как остров рисует календарь: IslandAppearance.calendar
  var appearance: CalendarAppearance {
    var appearance = CalendarAppearance()
    appearance.usesCalendarColor = useColor
    appearance.coloredIndicator = coloredIndicator
    appearance.monthView = monthView
    appearance.eventIndicators = eventIndicators
    return appearance
  }

  /// Окно и напоминание Before event starts: CalendarClock
  var clockSettings: CalendarClock.Settings {
    // Disable activity during events: компакт уходит после peek на старте, а без peek — в момент старта
    let peek = rules.peeksOnStart ? peekSeconds + 0.2 : 0
    return CalendarClock.Settings(
      lead: lead, remindsBeforeStart: quickPeek && peekBeforeStart, coloredIndicator: coloredIndicator,
      hidingAfterStart: disableDuringEvents ? peek : nil)
  }

  func mode(for calendarID: String) -> CalendarDisplayMode { filter.mode(for: calendarID) }

  func isIncluded(_ calendarID: String) -> Bool { !excluded.contains(calendarID) }

  func setIncluded(_ included: Bool, _ calendarID: String) {
    if included { excluded.remove(calendarID) } else { excluded.insert(calendarID) }
  }

  func setMode(_ mode: CalendarDisplayMode, _ calendarID: String) {
    modes[calendarID] = mode == .both ? nil : mode
  }

  private func save<T: Equatable>(_ old: T, _ new: T, _ key: String) {
    guard old != new else { return }
    defaults.set(new, forKey: key)
    onChange()
  }

  nonisolated private static func read<T>(_ defaults: UserDefaults, _ key: String, _ fallback: T) -> T {
    defaults.object(forKey: key) as? T ?? fallback
  }
}
