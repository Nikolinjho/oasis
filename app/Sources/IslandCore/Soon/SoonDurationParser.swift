import Foundation

public enum SoonDurationError: Error, Equatable, Sendable, LocalizedError {
  case empty, invalidFormat, invalidComponent, outOfRange

  public var errorDescription: String? {
    switch self {
    case .empty: "Укажи время, например 15 мин."
    case .invalidFormat: "Используй целые числа: 15 мин или 1 ч 20 мин."
    case .invalidComponent: "Проверь единицы и порядок: часы, минуты, секунды."
    case .outOfRange: "Время должно быть от 10 секунд до 24 часов."
    }
  }
}

public enum SoonDurationParser {
  private struct Component {
    var value: Int
    var unit: Int
  }

  public static func parse(_ input: String) throws -> Int {
    let scalars = Array(input.lowercased().unicodeScalars)
    var index = 0
    var components: [Component] = []
    skipWhitespace(scalars, index: &index)
    guard index < scalars.count else { throw SoonDurationError.empty }
    while index < scalars.count {
      guard isDigit(scalars[index]) else { throw SoonDurationError.invalidFormat }
      var value = 0
      while index < scalars.count, isDigit(scalars[index]) {
        let multiplied = value.multipliedReportingOverflow(by: 10)
        let added = multiplied.partialValue.addingReportingOverflow(Int(scalars[index].value - 48))
        guard !multiplied.overflow, !added.overflow else { throw SoonDurationError.outOfRange }
        value = added.partialValue
        index += 1
      }
      skipWhitespace(scalars, index: &index)
      if index == scalars.count {
        guard components.isEmpty else { throw SoonDurationError.invalidFormat }
        return try total([Component(value: value, unit: 60)])
      }
      let unitStart = index
      while index < scalars.count, !isDigit(scalars[index]), !scalars[index].properties.isWhitespace {
        index += 1
      }
      let text = String(String.UnicodeScalarView(scalars[unitStart..<index]))
      let unit: Int
      switch text {
      case "s", "sec", "сек", "с": unit = 1
      case "m", "min", "мин", "м": unit = 60
      case "h", "hr", "ч", "час", "часа", "часов": unit = 3_600
      default: throw SoonDurationError.invalidComponent
      }
      guard components.last.map({ $0.unit > unit }) ?? true else { throw SoonDurationError.invalidComponent }
      components.append(Component(value: value, unit: unit))
      skipWhitespace(scalars, index: &index)
    }
    return try total(components)
  }

  private static func total(_ components: [Component]) throws -> Int {
    var result = 0
    for component in components {
      if components.count > 1, component.unit < 3_600, component.value > 59 {
        throw SoonDurationError.invalidComponent
      }
      let multiplied = component.value.multipliedReportingOverflow(by: component.unit)
      let added = result.addingReportingOverflow(multiplied.partialValue)
      guard !multiplied.overflow, !added.overflow else { throw SoonDurationError.outOfRange }
      result = added.partialValue
    }
    guard (10...86_400).contains(result) else { throw SoonDurationError.outOfRange }
    return result
  }

  private static func isDigit(_ scalar: Unicode.Scalar) -> Bool { (48...57).contains(scalar.value) }

  private static func skipWhitespace(_ scalars: [Unicode.Scalar], index: inout Int) {
    while index < scalars.count, scalars[index].properties.isWhitespace { index += 1 }
  }
}
