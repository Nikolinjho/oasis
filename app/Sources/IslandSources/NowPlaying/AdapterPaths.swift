import Foundation

public struct AdapterPaths: Equatable, Sendable {
  public let script: URL
  public let framework: URL

  /// Сначала Resources бандла, затем ALCOVE_ADAPTER_DIR (для тестов и swift run)
  public static func locate(
    bundle: Bundle = .main,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> AdapterPaths? {
    var directories: [URL] = []
    if let resources = bundle.resourceURL { directories.append(resources) }
    if let custom = environment["ALCOVE_ADAPTER_DIR"] { directories.append(URL(fileURLWithPath: custom)) }
    for directory in directories {
      let script = directory.appendingPathComponent("mediaremote-adapter.pl")
      let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework")
      if FileManager.default.fileExists(atPath: script.path), FileManager.default.fileExists(atPath: framework.path) {
        return AdapterPaths(script: script, framework: framework)
      }
    }
    return nil
  }
}
