import Foundation
import IslandCore
import IslandSources

/// Календарь приложения: источник EventKit, часы и настройки страницы Calendar.
/// Отдельно от AppDelegate: тот упёрся в лимит длины
@MainActor
final class CalendarBridge {
  let clock: CalendarClock
  /// Play hourly chime: звук идёт через store.onSound — как все звуки, при General → Play sounds
  let chime: HourlyChimeTimer
  private let store: IslandStore
  private let settings: CalendarSettings
  private var source: EventKitCalendarSource?
  private var task: Task<Void, Never>?

  /// Создаётся до первой ссылки: холодный запуск по calendar.remind закрепляет повестку ещё до didFinishLaunching
  init(store: IslandStore, settings: CalendarSettings) {
    self.store = store
    self.settings = settings
    clock = CalendarClock(store: store, settings: settings.clockSettings)
    chime = HourlyChimeTimer { [weak store] in store?.onSound(.chime) }
    chime.isEnabled = settings.isEnabled && settings.hourlyChime
    // повестка раскрытого к этому моменту уже в store.agenda: меню часов берёт пункты из неё
    store.onAgendaChange = { [weak clock, weak store] live in
      guard let clock, let store else { return }
      clock.update(live: live, expanded: store.agenda)
    }
    store.setCalendarFilter(settings.filter)
  }

  isolated deinit {
    task?.cancel()
  }

  func start() {
    let source = EventKitCalendarSource()
    task = Task { [store] in
      for await events in source.changes { store.apply(events: events) }
    }
    source.start()
    self.source = source
  }

  /// Список Calendars на странице настроек. До старта источника — пусто
  func calendars() -> [CalendarInfo] {
    source?.calendars() ?? []
  }

  /// Смена настроек Calendar применяется на лету: фильтр календарей и часы
  func apply() {
    store.setCalendarFilter(settings.filter)
    clock.apply(settings.clockSettings)
    chime.isEnabled = settings.isEnabled && settings.hourlyChime
  }
}
