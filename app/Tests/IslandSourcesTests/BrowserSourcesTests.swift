import Testing

@testable import IslandSources

struct BrowserSourcesTests {
  @Test(
    "Предварительные сборки браузеров — тоже браузеры",
    arguments: [
      "com.google.Chrome.canary", "com.apple.SafariTechnologyPreview", "com.microsoft.edgemac.Dev",
      "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Canary", "com.operasoftware.OperaGX",
    ])
  func previewBuilds(bundleID: String) {
    #expect(BrowserSources.contains(bundleID))
  }

  @Test("Музыкальные приложения и пустой bundle id — не браузеры")
  func notBrowsers() {
    #expect(!BrowserSources.contains("com.spotify.client"))
    #expect(!BrowserSources.contains("com.apple.Music"))
    #expect(!BrowserSources.contains(nil))
  }
}
