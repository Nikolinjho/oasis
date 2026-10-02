import Foundation
import Testing

@testable import IslandSources

/// Проверки на настоящем железе: HARDWARE_TESTS=1 swift test --filter HardwareTests
@Suite(.enabled(if: ProcessInfo.processInfo.environment["HARDWARE_TESTS"] == "1"))
struct HardwareTests {
  @Test("Громкость читается и пишется")
  func volume() throws {
    let control = VolumeControl()
    let level = try #require(control.volume)
    #expect((0...1).contains(level))
    control.setVolume(level)
    let after = try #require(control.volume)
    #expect(abs(after - level) < 0.01)
  }

  @Test("Яркость встроенного дисплея читается")
  func brightness() throws {
    let control = try #require(BrightnessControl())
    let level = try #require(control.level)
    #expect((0...1).contains(level))
  }
}
