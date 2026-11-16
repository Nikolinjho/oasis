import Foundation

/// Ширина обзора и каталога по включённым модулям. Минимум оставляет место камере и навигации.
public struct DashboardLayout: Equatable, Sendable {
  public let media: Bool
  public let calendar: Bool
  public let claude: Bool
  public let soon: Bool
  public let notchWidth: CGFloat

  public init(media: Bool, calendar: Bool, claude: Bool, soon: Bool, notchWidth: CGFloat = 185) {
    self.media = media
    self.calendar = calendar
    self.claude = claude
    self.soon = soon
    self.notchWidth = notchWidth
  }

  public var showsMiddleColumn: Bool { calendar || claude }

  public var moduleViews: [ExpandedView] {
    var views: [ExpandedView] = []
    if media && calendar { views.append(.duo) }
    if media { views.append(.player) }
    if calendar { views.append(.calendar) }
    if claude { views.append(.claude) }
    if soon { views.append(.soon) }
    return views
  }

  public func size(for view: ExpandedView) -> CGSize {
    let width: CGFloat
    if view == .modules {
      let count = CGFloat(moduleViews.count)
      width = 48 + count * 96 + max(0, count - 1) * 8
    } else {
      let columns: [CGFloat] = (media ? [184] : []) + (showsMiddleColumn ? [280] : []) + (soon ? [204] : [])
      width = 50 + columns.reduce(0, +) + CGFloat(max(0, columns.count - 1)) * 25
    }
    return CGSize(width: max(345, notchWidth + 160, width), height: ExpandedLayout.dashboard.height)
  }
}
