import Foundation
import IslandCore
import IslandUI

extension IslandStore {
  var spec: IslandShapeSpec {
    var spec = IslandGeometry.spec(
      for: model.surface, hasMedia: model.hasMedia, notch: notch,
      calendarIndicatorWidth: IslandView.calendarIndicatorWidth,
      reminderIndicatorWidth: IslandView.reminderIndicatorWidth, battery: appearance.battery,
      calendarWithMusic: model.showsMedia, volumeRow: model.volumeRowShown,
      expandedView: model.expandedView, navigation: model.config.dashboardNavigation)
    if agentsPanel.waitingCount > 0, Self.isRestSwipeSurface(model.surface), model.surface != .idle {
      spec.size.width = ActivityComposition.width(notchWidth: notch.width, calendar: model.calendarLive, music: model.showsMedia)
      if case .hoverNudge = model.surface { spec.size.width *= IslandGeometry.hoverNudgeWidthScale }
    }
    if model.surface == .expanded, model.expandedView == .agents {
      spec.size = CGSize(width: agentsPanel.width, height: agentsPanel.height)
      spec.bottomRadius = IslandGeometry.bottomRadius(forHeight: spec.size.height)
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
