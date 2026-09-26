import CoreGraphics
import Foundation

/// Решение «на экране с вырезом полноэкранное приложение» по списку окон CGWindowListCopyWindowInfo.
/// Полноэкранное = у активного приложения (не нашего) есть видимое окно слоя 0 размером ровно с экран,
/// вместе с полосой menu bar: развёрнутое на весь экран окно menu bar не закрывает и сюда не попадает.
/// Нужны только границы и слой окна: для них разрешение на запись экрана не требуется, только для имён
public enum FullscreenWindows {
    /// - Parameters:
    ///   - windows: окна из CGWindowListCopyWindowInfo(.optionOnScreenOnly, .excludeDesktopElements)
    ///   - screen: рамка экрана с вырезом в координатах CG (начало в левом верхнем углу главного экрана)
    public static func isFullscreen(windows: [[String: Any]], frontmostPID: pid_t?, ownPID: pid_t, screen: CGRect) -> Bool {
        guard let frontmostPID, frontmostPID != ownPID else { return false }
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == frontmostPID,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let boundsInfo = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo)
            else { return false }
            return matches(bounds, screen)
        }
    }

    /// Рамка экрана NSScreen (начало внизу слева главного экрана) в координатах CG
    public static func cgRect(ofScreenFrame frame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryScreenHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// Допуск в 1 pt на дробные координаты окон
    private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 1 && abs(a.minY - b.minY) <= 1
            && abs(a.width - b.width) <= 1 && abs(a.height - b.height) <= 1
    }
}
