import Foundation

/// Пути общие для приложения и скрипта statusline.
public enum ClaudeFiles {
  public static func directory(home: URL, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
    if let path = environment["OASIS_CLAUDE_DIR"], !path.isEmpty {
      return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }
    return home.appendingPathComponent("Library/Application Support/Oasis", isDirectory: true)
  }

  public static func limits(in directory: URL) -> URL { directory.appendingPathComponent("claude-limits.json") }
  public static func history(in directory: URL) -> URL { directory.appendingPathComponent("claude-limits-history.jsonl") }
  public static func statuslineConfig(in directory: URL) -> URL { directory.appendingPathComponent("claude-statusline.json") }
  public static func statuslineScript(in directory: URL) -> URL { directory.appendingPathComponent("claude-statusline.py") }
}
