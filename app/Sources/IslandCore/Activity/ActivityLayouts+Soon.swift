import Foundation

extension ActivityLayouts {
  public static let soonAccent = RGB(red: 1, green: 184 / 255, blue: 0)

  public static func soon(_ notice: SoonNotice) -> ActivityLayout {
    ActivityLayout(
      symbol: "clock.arrow.circlepath", symbolColor: soonAccent,
      indicator: .text("Soon", color: soonAccent),
      line: .init(bar: nil, title: notice.title), imageName: "soon")
  }
}
