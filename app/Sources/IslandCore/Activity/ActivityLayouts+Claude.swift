import Foundation

extension ActivityLayouts {
  public static let claudeOrange = RGB(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
  public static let limitGood = RGB(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
  public static let limitWarn = RGB(red: 1, green: 214 / 255, blue: 10 / 255)
  public static let limitLow = RGB(red: 1, green: 69 / 255, blue: 58 / 255)
  public static let limitTrack = RGB(red: 0.22, green: 0.22, blue: 0.22)

  public static let claudeIcon = ActivityLayout(
    symbol: "sparkle", symbolColor: claudeOrange, indicator: .text("", color: claudeOrange), imageName: "claude")

  public static func limitColor(remaining: Int) -> RGB {
    remaining > 50 ? limitGood : remaining >= 20 ? limitWarn : limitLow
  }

  /// У Claude есть только временный peek. Постоянный компакт остаётся музыке и календарю.
  public static func claude(_ notice: ClaudeNotice, calendar: Calendar) -> ActivityLayout {
    let title: String
    let trailing: String
    switch notice.reason {
    case .reset:
      title = "Claude · сброс окна"
      trailing = "\(notice.remaining)%"
    case .threshold, .runsOut:
      title = "Claude · 5 ч"
      if let runsOut = notice.runsOutAt {
        trailing = "\(notice.remaining)% · кончится в \(clock(runsOut, calendar: calendar))"
      } else if let resets = notice.resetsAt {
        trailing = "\(notice.remaining)% · до \(clock(resets, calendar: calendar))"
      } else {
        trailing = "\(notice.remaining)%"
      }
    }
    return ActivityLayout(
      symbol: "sparkle", symbolColor: claudeOrange,
      indicator: .ring(progress: Double(notice.remaining) / 100, color: limitColor(remaining: notice.remaining), track: limitTrack),
      line: .init(bar: claudeOrange, title: title, trailing: trailing), imageName: "claude")
  }

  public static func clock(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
  }
}
