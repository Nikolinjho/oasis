/// Содержимое peek Codex с длительностью окна из источника.
public struct CodexNotice: Equatable, Sendable {
  public var details: ClaudeNotice
  public var windowTitle: String

  public init(details: ClaudeNotice, windowTitle: String) {
    self.details = details
    self.windowTitle = windowTitle
  }
}
