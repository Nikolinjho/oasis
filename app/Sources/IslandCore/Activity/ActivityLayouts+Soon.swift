import Foundation

extension ActivityLayouts {
  public static let soonTeal = RGB(red: 45 / 255, green: 212 / 255, blue: 191 / 255)

  public static func soon(_ notice: SoonNotice) -> ActivityLayout {
    ActivityLayout(
      symbol: "checklist", symbolColor: soonTeal,
      indicator: .text("Soon", color: soonTeal),
      line: .init(bar: nil, title: notice.title))
  }
}
