import Foundation
import Testing

@testable import IslandSources

struct LineBufferTests {
  @Test("Строки склеиваются из кусков")
  func joinsChunks() {
    var buffer = LineBuffer()
    #expect(buffer.append(Data("a\nb".utf8)) == ["a"])
    #expect(buffer.append(Data("c\n".utf8)) == ["bc"])
    #expect(buffer.append(Data()).isEmpty)
  }

  @Test("UTF-8 символ, разрезанный между кусками, не ломается")
  func splitMultibyte() {
    var buffer = LineBuffer()
    let bytes = Array("♪ Fire\n".utf8)
    #expect(buffer.append(Data(bytes[0..<1])).isEmpty)
    #expect(buffer.append(Data(bytes[1...])) == ["♪ Fire"])
  }

  @Test("Несколько строк в одном куске")
  func manyLines() {
    var buffer = LineBuffer()
    #expect(buffer.append(Data("x\ny\nz".utf8)) == ["x", "y"])
  }
}
