import AppKit
import IslandSources

@MainActor
final class SoonAppIntegration {
  let module: SoonModule
  private let lifecycle = SoonModuleLifecycle()
  private let composer = SoonComposerController()

  init(store: IslandStore, settings: AppSettings) {
    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/Oasis/Soon", isDirectory: true)
    module = SoonModule(
      store: store, settings: settings, notifications: SoonNotifications(),
      url: directory.appendingPathComponent("reminders-v1.json"))
    module.composer = composer
    composer.submit = { [weak module] title, duration, mode in
      guard let module else { throw SoonModuleError.disabled }
      try await module.submit(title: title, duration: duration, mode: mode)
    }
    module.onStart = { [weak lifecycle, weak module] in
      if let module { lifecycle?.start(module) }
    }
    module.onStop = { [weak lifecycle] in lifecycle?.stop() }
  }

  func install() { module.notifications.install() }

  func menu(calendar: CalendarBridge, store: IslandStore, enabled: Bool) -> [NSMenuItem] {
    SoonMenuSection.items(module, enabled: enabled)
      + CalendarMenuSection.items(
        for: calendar.clock.menuModel(),
        actions: .init(
          join: { [store] url in store.onJoin(url) }, open: { CalendarMenuSection.open($0) },
          dismiss: { [calendar] id in calendar.clock.dismiss(id) }))
  }

  func start(window: IslandWindowController?) {
    composer.frame = { [weak window] in window?.composerFrame ?? .zero }
    composer.onEditing = { [weak window] active in window?.setComposerActive(active) }
    window?.onComposerSurfaceChange = { [weak composer] surface in composer?.surfaceChanged(surface) }
    module.start()
  }
}
