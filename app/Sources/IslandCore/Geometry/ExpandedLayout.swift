import Foundation

/// Общая геометрия формы, контента и безопасной полосы вокруг камеры.
public enum ExpandedLayout {
  public static let dashboard = CGSize(width: 768, height: 216)
  public static let headerHeight: CGFloat = 32

  public static func size(for view: ExpandedView, navigation: Bool, volumeRow: Bool = false) -> CGSize {
    if view == .overview || view == .modules { return dashboard }
    return CGSize(
      width: IslandGeometry.expanded.width,
      height: IslandGeometry.expanded.height + (navigation ? headerHeight : 0)
        + (volumeRow ? IslandGeometry.volumeRowHeight : 0))
  }
}
