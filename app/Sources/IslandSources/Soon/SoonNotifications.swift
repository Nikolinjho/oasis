import Foundation
import IslandCore
import UserNotifications

public struct SoonNotificationAction: Sendable {
  public enum Kind: Sendable { case open, complete, snooze }
  public let id: UUID
  public let revision: Int
  public let kind: Kind
}

/// Один последовательный проход согласования: старый add не может отменить новую ревизию.
@MainActor
public final class SoonNotifications: NSObject, UNUserNotificationCenterDelegate {
  private let center: UNUserNotificationCenter
  private let prefix: String
  private var desired: [SoonReminder] = []
  private var enabled = false
  private var sound = false
  private var generation = 0
  private var worker: Task<Void, Never>?
  private var actionHandler: ((SoonNotificationAction) -> Void)?
  private var bufferedActions: [SoonNotificationAction] = []
  public var onStatus: (SoonDeliveryStatus) -> Void = { _ in }
  public private(set) var status = SoonDeliveryStatus()

  public init(prefix: String = "soon.", center: UNUserNotificationCenter = .current()) {
    self.prefix = prefix
    self.center = center
    super.init()
  }

  public func install() {
    center.delegate = self
    let actions = [
      UNNotificationAction(identifier: "soon.complete", title: "Готово", options: []),
      UNNotificationAction(identifier: "soon.snooze", title: "+5 мин", options: []),
    ]
    center.setNotificationCategories([
      UNNotificationCategory(identifier: "oasis.soon", actions: actions, intentIdentifiers: [], options: [])
    ])
  }

  public func handleActions(_ handler: @escaping (SoonNotificationAction) -> Void) {
    actionHandler = handler
    let actions = bufferedActions
    bufferedActions.removeAll()
    actions.forEach(handler)
  }

  public func requestAuthorization() async {
    do {
      let settings = await center.notificationSettings()
      if settings.authorizationStatus == .notDetermined {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
      }
      await refreshAuthorization()
    } catch {
      status.error = error.localizedDescription
      publish()
    }
  }

  public func refreshAuthorization() async {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .authorized: status.authorization = .authorized
    case .provisional, .ephemeral: status.authorization = .provisional
    case .denied: status.authorization = .denied
    case .notDetermined: status.authorization = .notDetermined
    @unknown default: status.authorization = .unknown
    }
    publish()
  }

  public func synchronize(_ reminders: [SoonReminder], enabled: Bool, sound: Bool) async {
    desired = reminders
    self.enabled = enabled
    self.sound = sound
    generation += 1
    if worker == nil {
      worker = Task { [weak self] in await self?.drain() }
    }
    await worker?.value
  }

  /// При Quit этот метод не вызывается: запросы остаются у macOS.
  public func cancelAll() async { await synchronize([], enabled: false, sound: false) }

  private func drain() async {
    var processed = -1
    while processed != generation {
      processed = generation
      await reconcile(generation: processed)
    }
    worker = nil
  }

  private func reconcile(generation pass: Int) async {
    await refreshAuthorization()
    guard pass == generation else { return }
    let active = enabled && (status.authorization == .authorized || status.authorization == .provisional)
    let records = active ? desired.filter { $0.state != .completed } : []
    let retainedIDs = Set(records.map { identifier($0) })
    let pending = await center.pendingNotificationRequests()
    guard pass == generation else { return }
    let delivered = await center.deliveredNotifications()
    guard pass == generation else { return }
    let obsoletePending = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && !retainedIDs.contains($0) }
    let obsoleteDelivered = delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) && !retainedIDs.contains($0) }
    center.removePendingNotificationRequests(withIdentifiers: obsoletePending)
    center.removeDeliveredNotifications(withIdentifiers: obsoleteDelivered)
    status.error = nil
    var scheduled = Set(pending.map(\.identifier)).intersection(retainedIDs)
    for reminder in records where reminder.state == .scheduled && reminder.dueAt > Date() {
      guard pass == generation else { break }
      let request = request(for: reminder)
      do {
        try await center.add(request)
        // Если срок успел изменить другой проход, убираем только устаревший identifier.
        let stillDesired = enabled && desired.contains { identifier($0) == request.identifier && $0.state != .completed }
        if stillDesired {
          scheduled.insert(request.identifier)
        } else {
          center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        }
      } catch {
        if pass == generation { status.error = error.localizedDescription }
        scheduled.remove(request.identifier)
      }
    }
    guard pass == generation else { return }
    status.scheduledIDs = scheduled
    publish()
  }

  private func identifier(_ reminder: SoonReminder) -> String {
    prefix + reminder.id.uuidString + "." + String(reminder.revision)
  }

  private func request(for reminder: SoonReminder) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "Soon"
    content.body = reminder.title
    content.threadIdentifier = "oasis.soon"
    content.categoryIdentifier = "oasis.soon"
    content.userInfo = ["id": reminder.id.uuidString, "revision": reminder.revision]
    if sound { content.sound = .default }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.dueAt)
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    return UNNotificationRequest(
      identifier: identifier(reminder), content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
  }

  private func publish() { onStatus(status) }

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    guard notification.request.identifier.hasPrefix("soon.") else { return [] }
    return [.banner, .list, .sound]
  }

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    let info = response.notification.request.content.userInfo
    guard let rawID = info["id"] as? String, let id = UUID(uuidString: rawID),
      let revision = info["revision"] as? Int,
      response.actionIdentifier != UNNotificationDismissActionIdentifier
    else { return }
    let kind: SoonNotificationAction.Kind
    switch response.actionIdentifier {
    case "soon.complete": kind = .complete
    case "soon.snooze": kind = .snooze
    default: kind = .open
    }
    let action = SoonNotificationAction(id: id, revision: revision, kind: kind)
    await MainActor.run {
      if let actionHandler { actionHandler(action) } else { bufferedActions.append(action) }
    }
  }
}
