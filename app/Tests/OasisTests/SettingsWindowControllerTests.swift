import AppKit
import Testing

@testable import Oasis

@Suite(.serialized)
@MainActor
struct SettingsWindowControllerTests {
  @Test("Открытие настроек показывает приложение в Dock, закрытие возвращает фоновый режим")
  func dockFollowsSettingsWindow() async throws {
    let app = NSApplication.shared
    let originalPolicy = app.activationPolicy()
    defer { app.setActivationPolicy(originalPolicy) }
    app.setActivationPolicy(.accessory)
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let controller = SettingsWindowController(settings: AppSettings(defaults: defaults))

    controller.show()
    let window = try #require(app.windows.first { $0.title == "General" && $0.isVisible })
    defer { window.close() }
    #expect(app.activationPolicy() == .regular)
    window.close()
    await Task.yield()
    #expect(app.activationPolicy() == .accessory)
    #expect(!window.isVisible)
    controller.show()
    #expect(app.activationPolicy() == .regular)
    #expect(window.isVisible)
  }

  @Test("Повторное открытие поднимает существующее окно настроек")
  func reusesSettingsWindow() throws {
    let app = NSApplication.shared
    let originalPolicy = app.activationPolicy()
    defer { app.setActivationPolicy(originalPolicy) }
    let (name, defaults) = TestDefaults.fresh()
    defer { TestDefaults.cleanup(name, defaults) }
    let controller = SettingsWindowController(settings: AppSettings(defaults: defaults))

    controller.show()
    let window = try #require(app.windows.first { $0.title == "General" && $0.isVisible })
    defer { window.close() }
    window.orderOut(nil)
    controller.show()
    #expect(window.isVisible)
    #expect(app.windows.filter { $0.title == "General" && $0.isVisible }.count == 1)
  }
}
