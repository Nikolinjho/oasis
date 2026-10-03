import AppKit
import Foundation
import IslandCore

/// Play hourly chime: спит до начала следующего часа и звонит. После сна и смены системного времени
/// пересчитывает час заново: таймер, проспавший час, не звонит с опозданием (HourlyChime.isOnTime)
@MainActor
final class HourlyChimeTimer {
  var isEnabled = false {
    didSet { if isEnabled != oldValue { reschedule() } }
  }
  /// Начало часа, к которому сейчас ждёт таймер. Выключен — nil
  private(set) var target: Date?
  private let play: () -> Void
  private var task: Task<Void, Never>?
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []

  init(play: @escaping () -> Void) {
    self.play = play
    let wake: [(NotificationCenter, Notification.Name)] = [
      (.default, .NSSystemClockDidChange),
      (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
    ]
    observers = wake.map { center, name in
      (
        center,
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.reschedule() }
        }
      )
    }
  }

  isolated deinit {
    task?.cancel()
    for (center, token) in observers { center.removeObserver(token) }
  }

  func reschedule(now: Date = Date()) {
    task?.cancel()
    task = nil
    guard isEnabled else {
      target = nil
      return
    }
    let next = HourlyChime.next(after: now)
    target = next
    task = Task { [weak self] in
      try? await Task.sleep(for: .seconds(next.timeIntervalSince(now)))
      guard !Task.isCancelled, let self else { return }
      if HourlyChime.isOnTime(fired: Date(), target: next) { play() }
      reschedule()
    }
  }
}
