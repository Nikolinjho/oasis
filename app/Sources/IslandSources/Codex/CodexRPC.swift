import Foundation
import IslandCore

/// Значения протокола не попадают в диагностические сообщения.
enum CodexJSON: Codable, Sendable {
  case object([String: CodexJSON])
  case array([CodexJSON])
  case string(String)
  case number(Int64)
  case decimal(Double)
  case bool(Bool)
  case null

  init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer()
    if value.decodeNil() {
      self = .null
    } else if let item = try? value.decode(Bool.self) {
      self = .bool(item)
    } else if let item = try? value.decode(Int64.self) {
      self = .number(item)
    } else if let item = try? value.decode(Double.self) {
      self = .decimal(item)
    } else if let item = try? value.decode(String.self) {
      self = .string(item)
    } else if let item = try? value.decode([String: CodexJSON].self) {
      self = .object(item)
    } else {
      self = .array(try value.decode([CodexJSON].self))
    }
  }

  func encode(to encoder: any Encoder) throws {
    var value = encoder.singleValueContainer()
    switch self {
    case .object(let item): try value.encode(item)
    case .array(let item): try value.encode(item)
    case .string(let item): try value.encode(item)
    case .number(let item): try value.encode(item)
    case .decimal(let item): try value.encode(item)
    case .bool(let item): try value.encode(item)
    case .null: try value.encodeNil()
    }
  }

  subscript(_ key: String) -> CodexJSON? {
    guard case .object(let object) = self else { return nil }
    return object[key]
  }

  var string: String? {
    guard case .string(let string) = self else { return nil }
    return string
  }

  func decode<T: Decodable>(_ type: T.Type) -> T? {
    guard let data = try? JSONEncoder().encode(self) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

struct CodexLoadedThreads: Decodable {
  let data: [String]
  let nextCursor: String?
}

struct CodexInputParams: Decodable {
  let threadId: String
  let turnId: String
  let itemId: String
  let questions: [CodexQuestion]
  let isBlocking: Bool
}
