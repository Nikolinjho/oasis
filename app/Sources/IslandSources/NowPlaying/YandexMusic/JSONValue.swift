import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer()
    if value.decodeNil() {
      self = .null
    } else if let object = try? value.decode([String: JSONValue].self) {
      self = .object(object)
    } else if let array = try? value.decode([JSONValue].self) {
      self = .array(array)
    } else if let boolean = try? value.decode(Bool.self) {
      self = .bool(boolean)
    } else if let number = try? value.decode(Double.self) {
      self = .number(number)
    } else {
      self = .string(try value.decode(String.self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var value = encoder.singleValueContainer()
    switch self {
    case .object(let object): try value.encode(object)
    case .array(let array): try value.encode(array)
    case .string(let string): try value.encode(string)
    case .number(let number): try value.encode(number)
    case .bool(let boolean): try value.encode(boolean)
    case .null: try value.encodeNil()
    }
  }

  public subscript(key: String) -> JSONValue {
    if case .object(let values) = self { return values[key] ?? .null }
    return .null
  }
  public var string: String? {
    if case .string(let value) = self { return value }
    return nil
  }
  public var double: Double? {
    if case .number(let value) = self { return value }
    return nil
  }
  public var int: Int? { double.flatMap { $0.isFinite && $0 >= Double(Int.min) && $0 < Double(Int.max) ? Int($0) : nil } }
  public var bool: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }
  public var array: [JSONValue]? {
    if case .array(let value) = self { return value }
    return nil
  }
  public var json: String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? "null" }
}
