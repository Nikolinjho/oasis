import CoreGraphics

public struct IslandShapeSpec: Equatable, Sendable {
    public var size: CGSize
    public var bottomRadius: CGFloat

    public init(size: CGSize, bottomRadius: CGFloat) {
        self.size = size
        self.bottomRadius = bottomRadius
    }
}

/// Размеры состояний из capture/analysis/README.md (MacBook Pro 16")
public enum IslandGeometry {
    public static let compact = CGSize(width: 261, height: 32)
    public static let peek = CGSize(width: 283, height: 51)
    public static let hoverWithMedia = CGSize(width: 190, height: 73)
    public static let hoverEmpty = CGSize(width: 203, height: 90)
    public static let expanded = CGSize(width: 370, height: 175)
    public static let hud = CGSize(width: 374, height: 32)
    /// Ширина, до которой остров сжимается при смене активности
    public static let shrinkWidth: CGFloat = 195

    /// Вогнутые плечи по бокам: форма перетекает в menu bar
    public static let shoulder: CGFloat = 7
    /// Окно под самое большое состояние с перелётом (пик раскрытия 382×187.5) и плечами
    public static let windowSize = CGSize(width: 440, height: 210)

    public static func spec(for surface: Surface, hasMedia: Bool, notch: CGSize) -> IslandShapeSpec {
        let size: CGSize = switch surface {
        case .idle: notch
        case .compact: compact
        case .peek: peek
        case .hover: hasMedia ? hoverWithMedia : hoverEmpty
        case .expanded: expanded
        case .shrink: CGSize(width: shrinkWidth, height: notch.height)
        case .hud: hud
        }
        return IslandShapeSpec(size: size, bottomRadius: bottomRadius(forHeight: size.height))
    }

    /// Радиус нижних углов. Оценка по кадрам capture/analysis, уточняется при сверке в задаче 16
    public static func bottomRadius(forHeight height: CGFloat) -> CGFloat {
        switch height {
        case ..<40: 10
        case ..<60: 14
        case ..<100: 18
        default: 28
        }
    }

    /// Рамка окна: верх у края экрана, по центру выреза
    public static func windowFrame(for metrics: NotchMetrics) -> CGRect {
        CGRect(
            x: metrics.screenFrame.midX - windowSize.width / 2,
            y: metrics.screenFrame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height)
    }

    /// Контур острова вместе с плечами в координатах экрана
    public static func islandScreenRect(_ spec: IslandShapeSpec, windowFrame: CGRect) -> CGRect {
        let width = spec.size.width + 2 * shoulder
        return CGRect(
            x: windowFrame.midX - width / 2,
            y: windowFrame.maxY - spec.size.height,
            width: width,
            height: spec.size.height)
    }

    /// Зона hover в покое: вырез ±30 pt по бокам и 6 pt вниз
    public static func hoverZone(for metrics: NotchMetrics) -> CGRect {
        let notch = metrics.notchRect
        return CGRect(x: notch.minX - 30, y: notch.minY - 6, width: notch.width + 60, height: notch.height + 6)
    }
}
