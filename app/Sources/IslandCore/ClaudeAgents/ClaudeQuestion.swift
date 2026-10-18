import Foundation

public struct ClaudeQuestion: Codable, Equatable, Sendable {
  public struct Option: Codable, Equatable, Sendable {
    public let label: String
    public let description: String

    public init(label: String, description: String = "") {
      self.label = label
      self.description = description
    }
  }

  public let text: String
  public let header: String
  public let options: [Option]
  public let multiSelect: Bool

  public init(text: String, header: String, options: [Option], multiSelect: Bool) {
    self.text = text
    self.header = header
    self.options = options
    self.multiSelect = multiSelect
  }
}
