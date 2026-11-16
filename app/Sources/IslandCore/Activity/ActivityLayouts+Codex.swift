import Foundation

extension ActivityLayouts {
  public static func codex(_ notice: CodexNotice, calendar: Calendar) -> ActivityLayout {
    var layout = claude(notice.details, calendar: calendar)
    let color = RGB(red: 1, green: 1, blue: 1)
    layout.symbol = "terminal"
    layout.symbolColor = color
    layout.imageName = nil
    layout.line?.bar = color
    layout.line?.title = notice.details.reason == .reset ? "Codex · сброс окна" : "Codex · \(notice.windowTitle)"
    return layout
  }
}
