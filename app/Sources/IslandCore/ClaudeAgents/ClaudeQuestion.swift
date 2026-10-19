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
  public let isSecret: Bool
  public let allowsOther: Bool

  private enum CodingKeys: String, CodingKey { case text, header, options, multiSelect, isSecret, allowsOther }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    text = try values.decode(String.self, forKey: .text)
    header = try values.decode(String.self, forKey: .header)
    options = try values.decode([Option].self, forKey: .options)
    multiSelect = try values.decode(Bool.self, forKey: .multiSelect)
    isSecret = try values.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
    allowsOther = try values.decodeIfPresent(Bool.self, forKey: .allowsOther) ?? true
  }

  public init(text: String, header: String, options: [Option], multiSelect: Bool, isSecret: Bool = false, allowsOther: Bool = true) {
    self.text = text
    self.header = header
    self.options = options
    self.multiSelect = multiSelect
    self.isSecret = isSecret
    self.allowsOther = allowsOther
  }
}
