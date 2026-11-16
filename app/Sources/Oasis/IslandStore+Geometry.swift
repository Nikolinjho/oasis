import Foundation
import IslandCore
import IslandUI

extension IslandStore {
  var spec: IslandShapeSpec {
    PeekQueueGeometry.islandSpec(contentSpec, appearance: appearance.peekQueue, visible: showsPeekQueue)
  }

  var showsPeekQueue: Bool {
    PeekQueueGeometry.isVisible(surface: model.surface, count: queuedPeeks.count)
  }

  var contentSpec: IslandShapeSpec {
    var spec = IslandGeometry.spec(
      for: model.surface, hasMedia: model.hasMedia, notch: notch,
      calendarIndicatorWidth: IslandView.calendarIndicatorWidth,
      reminderIndicatorWidth: IslandView.reminderIndicatorWidth, battery: appearance.battery,
      calendarWithMusic: model.showsMedia, volumeRow: model.volumeRowShown,
      expandedView: model.expandedView, navigation: model.config.dashboardNavigation)
    if model.surface == .expanded, model.expandedView == .overview || model.expandedView == .modules {
      spec.size = DashboardLayout(
        media: mediaEnabled, calendar: calendarFilter.isEnabled, claude: claudePanel != nil, codex: codexPanel != nil,
        soon: soonPanel != nil, notchWidth: notch.width
      ).size(for: model.expandedView)
    }
    if model.surface == .expanded, stretch != 0 {
      spec.size.height += stretch
      // IslandGeometry.spec тоже держит радиус по высоте без строки громкости (комментарий у bottomRadius):
      // без вычитания радиус на старте свайпа скакнул бы с 35 (175) на ~40.5 (207+stretch)
      let radiusHeight = spec.size.height - (model.volumeRowShown ? IslandGeometry.volumeRowHeight : 0)
      spec.bottomRadius = IslandGeometry.bottomRadius(forHeight: radiusHeight)
    }
    return spec
  }

}
