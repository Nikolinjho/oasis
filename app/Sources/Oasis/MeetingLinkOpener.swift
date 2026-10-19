import AppKit
import IslandCore

@MainActor
enum MeetingLinkOpener {
  static func open(_ url: URL) {
    let workspace = NSWorkspace.shared
    guard MeetingService(url: url) == .googleMeet,
      let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
      let app = workspace.urlForApplication(
        withBundleIdentifier: "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"),
      let bundle = Bundle(url: app),
      let browserID = bundle.object(forInfoDictionaryKey: "CrBundleIdentifier") as? String,
      let browser = workspace.urlForApplication(withBundleIdentifier: browserID),
      let appID = bundle.object(forInfoDictionaryKey: "CrAppModeShortcutID") as? String
    else {
      workspace.open(url)
      return
    }

    // Открытие HTTPS через shim Meet теряет адрес встречи. Новый процесс Chrome передаёт
    // аргументы уже работающему браузеру и открывает комнату в установленном приложении.
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.arguments = [
      "--app-id=\(appID)",
      "--app-launch-url-for-shortcuts-menu-item=\(url.absoluteString)",
    ]
    Task {
      do {
        _ = try await workspace.openApplication(at: browser, configuration: configuration)
      } catch {
        workspace.open(url)
      }
    }
  }
}
