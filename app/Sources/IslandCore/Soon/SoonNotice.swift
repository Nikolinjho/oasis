import Foundation

public enum SoonSoundChannel: String, Equatable, Sendable {
  case native, island, none
}

public struct SoonNotice: Equatable, Sendable {
  public var occurrenceID: String
  public var title: String
  public var reminderIDs: [UUID]
  public var catchUp: Bool
  public var soundChannel: SoonSoundChannel

  public init(
    occurrenceID: String, title: String, reminderIDs: [UUID], catchUp: Bool = false,
    soundChannel: SoonSoundChannel = .none
  ) {
    self.occurrenceID = occurrenceID
    self.title = title
    self.reminderIDs = reminderIDs
    self.catchUp = catchUp
    self.soundChannel = soundChannel
  }

  public init(reminder: SoonReminder, catchUp: Bool = false, soundChannel: SoonSoundChannel = .none) {
    self.init(
      occurrenceID: reminder.occurrenceID, title: reminder.title, reminderIDs: [reminder.id],
      catchUp: catchUp, soundChannel: soundChannel)
  }

  public static func summary(_ reminders: [SoonReminder], soundChannel: SoonSoundChannel = .none) -> SoonNotice? {
    guard let first = reminders.first else { return nil }
    return SoonNotice(
      occurrenceID: first.occurrenceID,
      title: reminders.count == 1 ? first.title : "Напоминаний: \(reminders.count)",
      reminderIDs: reminders.map(\.id), catchUp: true, soundChannel: soundChannel)
  }
}
