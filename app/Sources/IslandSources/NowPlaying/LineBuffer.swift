import Foundation

/// Склеивает куски вывода процесса в строки по \n
public struct LineBuffer: Sendable {
  private var pending = Data()

  public init() {}

  public mutating func append(_ chunk: Data) -> [String] {
    pending.append(chunk)
    var lines: [String] = []
    while let newline = pending.firstIndex(of: 0x0A) {
      lines.append(String(decoding: pending[pending.startIndex..<newline], as: UTF8.self))
      pending.removeSubrange(pending.startIndex...newline)
    }
    return lines
  }
}
