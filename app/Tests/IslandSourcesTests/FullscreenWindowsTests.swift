import CoreGraphics
import Foundation
import Testing
@testable import IslandSources

struct FullscreenWindowsTests {
    /// Встроенный экран MacBook Pro 16" главный: в координатах CG он же (0, 0, 1728, 1117)
    static let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    static func window(pid: pid_t, layer: Int = 0, _ bounds: CGRect) -> [String: Any] {
        [
            kCGWindowOwnerPID as String: NSNumber(value: pid),
            kCGWindowLayer as String: NSNumber(value: layer),
            kCGWindowBounds as String: bounds.dictionaryRepresentation,
        ]
    }

    @Test("Окно активного приложения во весь экран — полноэкранное")
    func fullscreenWindow() {
        let windows = [Self.window(pid: 42, Self.screen)]
        #expect(FullscreenWindows.isFullscreen(windows: windows, frontmostPID: 42, ownPID: 1, screen: Self.screen))
    }

    @Test("Развёрнутое окно под menu bar полноэкранным не считается")
    func zoomedWindow() {
        let windows = [Self.window(pid: 42, CGRect(x: 0, y: 32, width: 1728, height: 1085))]
        #expect(!FullscreenWindows.isFullscreen(windows: windows, frontmostPID: 42, ownPID: 1, screen: Self.screen))
    }

    @Test("Полноэкранное окно неактивного приложения не считается")
    func backgroundApp() {
        let windows = [Self.window(pid: 7, Self.screen), Self.window(pid: 42, CGRect(x: 100, y: 100, width: 800, height: 600))]
        #expect(!FullscreenWindows.isFullscreen(windows: windows, frontmostPID: 42, ownPID: 1, screen: Self.screen))
    }

    @Test("Окна не слоя 0 (оверлеи, наша панель) и наше приложение активным не считаются")
    func overlaysAndSelf() {
        let overlay = [Self.window(pid: 42, layer: 25, Self.screen)]
        #expect(!FullscreenWindows.isFullscreen(windows: overlay, frontmostPID: 42, ownPID: 1, screen: Self.screen))
        let own = [Self.window(pid: 1, Self.screen)]
        #expect(!FullscreenWindows.isFullscreen(windows: own, frontmostPID: 1, ownPID: 1, screen: Self.screen))
        #expect(!FullscreenWindows.isFullscreen(windows: own, frontmostPID: nil, ownPID: 1, screen: Self.screen))
    }

    @Test("Полноэкранное на другом мониторе для экрана с вырезом не считается")
    func otherDisplay() {
        let external = CGRect(x: 1728, y: -200, width: 2560, height: 1440)
        let windows = [Self.window(pid: 42, external)]
        #expect(!FullscreenWindows.isFullscreen(windows: windows, frontmostPID: 42, ownPID: 1, screen: Self.screen))
    }

    @Test("Рамка NSScreen переводится в координаты CG от верха главного экрана")
    func coordinates() {
        // внешний монитор выше встроенного: в NSScreen y растёт вверх
        let frame = CGRect(x: 0, y: 1117, width: 2560, height: 1440)
        #expect(FullscreenWindows.cgRect(ofScreenFrame: frame, primaryScreenHeight: 1117) == CGRect(x: 0, y: -1440, width: 2560, height: 1440))
        #expect(FullscreenWindows.cgRect(ofScreenFrame: Self.screen, primaryScreenHeight: 1117) == Self.screen)
    }
}
