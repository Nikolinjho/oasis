import AppKit
import IslandCore

@MainActor
enum SoonMenuSection {
  static func items(_ module: SoonModule, enabled: Bool) -> [NSMenuItem] {
    guard enabled else { return [] }
    var items: [NSMenuItem] = [
      ClosureMenuItem("New Reminder…") { module.perform(.create) },
      ClosureMenuItem("Soon…") { module.perform(.showList) },
      ClosureMenuItem("Completed…") { module.perform(.showCompleted) },
    ]
    let upcoming = SoonSchedule.sorted(module.reminders, now: Date()).prefix(3)
    for reminder in upcoming {
      let time = reminder.state == .due ? "Пора" : reminder.dueAt.formatted(date: .omitted, time: .shortened)
      items.append(
        ClosureMenuItem("\(time) · \(reminder.title)") {
          module.perform(.open(id: reminder.id, revision: reminder.revision))
        })
    }
    return items
  }
}
