import Foundation

public enum SoonAuthorization: String, Equatable, Sendable {
  case unknown, notDetermined, denied, authorized, provisional
}

public struct SoonDeliveryStatus: Equatable, Sendable {
  public var authorization: SoonAuthorization
  public var scheduledIDs: Set<String>
  public var error: String?

  public init(
    authorization: SoonAuthorization = .unknown, scheduledIDs: Set<String> = [], error: String? = nil
  ) {
    self.authorization = authorization
    self.scheduledIDs = scheduledIDs
    self.error = error
  }

  public var eligibleNative: Bool { authorization == .authorized || authorization == .provisional }
}

public struct SoonPanel: Equatable, Sendable {
  public var reminders: [SoonReminder]
  public var now: Date
  public var selectedID: UUID?
  public var showsCompleted: Bool
  public var deliveryStatus: SoonDeliveryStatus

  public init(
    reminders: [SoonReminder], now: Date, selectedID: UUID? = nil,
    showsCompleted: Bool = false, deliveryStatus: SoonDeliveryStatus = SoonDeliveryStatus()
  ) {
    self.reminders = reminders
    self.now = now
    self.selectedID = selectedID
    self.showsCompleted = showsCompleted
    self.deliveryStatus = deliveryStatus
  }

  public var visibleReminders: [SoonReminder] {
    SoonSchedule.sorted(reminders, now: now, includeCompleted: showsCompleted)
  }

  public var selected: SoonReminder? { reminders.first { $0.id == selectedID } }
}

public enum SoonAction: Equatable, Sendable {
  case create
  case showList
  case showCompleted
  case open(id: UUID, revision: Int)
  case complete(id: UUID, revision: Int)
  case delete(id: UUID, revision: Int)
  case edit(id: UUID, revision: Int)
  case snooze(id: UUID, revision: Int, seconds: Int)
  case repeatReminder(id: UUID, revision: Int)
  case customSnooze(id: UUID, revision: Int)
  case clearCompleted
}
