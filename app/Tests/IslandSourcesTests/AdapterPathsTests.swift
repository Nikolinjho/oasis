import Foundation
import Testing

@testable import IslandSources

struct AdapterPathsTests {
  static func makeAdapterDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: dir.appendingPathComponent("MediaRemoteAdapter.framework"), withIntermediateDirectories: true)
    try Data().write(to: dir.appendingPathComponent("mediaremote-adapter.pl"))
    return dir
  }

  @Test("Адаптер находится по ALCOVE_ADAPTER_DIR")
  func fromEnvironment() throws {
    let dir = try Self.makeAdapterDir()
    let paths = try #require(AdapterPaths.locate(bundle: Bundle(for: BundleToken.self), environment: ["ALCOVE_ADAPTER_DIR": dir.path]))
    #expect(paths.script.lastPathComponent == "mediaremote-adapter.pl")
    #expect(paths.framework.lastPathComponent == "MediaRemoteAdapter.framework")
  }

  @Test("Без адаптера — nil")
  func missing() {
    #expect(AdapterPaths.locate(bundle: Bundle(for: BundleToken.self), environment: [:]) == nil)
  }
}

private final class BundleToken {}
