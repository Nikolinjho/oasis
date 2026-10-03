/// Calendar (ui-inspection 1.9): что машина делает на старте события и с напоминанием.
/// Когда открывается окно и какие события в него попадают, решают CalendarSchedule и CalendarFilter
public struct CalendarRules: Equatable, Sendable {
  /// Extension → Quick Peek и When event is starting: peek с названием на старте. Выкл — только звук
  public var peeksOnStart = true
  /// Extension → Peek duration: peek на старте и напоминание Before event starts
  public var peekDuration: Duration = IslandTiming.calendarPeek
  /// Play sound on calendar event: звук на старте и на напоминании
  public var sound = true

  public init() {}

  /// peekDuration в секундах: Disable activity during events держит компакт ровно на время peek
  public var peekInterval: Double {
    let parts = peekDuration.components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
  }

  /// Peek duration 4 с держится 4.2 с (замер ui-inspection 3.5): к настройке прибавляем 0.2 с
  public static func peekDuration(seconds: Double) -> Duration {
    .milliseconds(Int((seconds * 1000).rounded()) + 200)
  }
}
