import Foundation
import IslandCore
import Testing

@testable import IslandSources

struct AccentCacheTests {
  static let red = AccentCache.Colors(accent: RGB(red: 1, green: 0, blue: 0), bottom: nil)
  static let artwork = Data([1, 2, 3])

  @Test("Посчитанные цвета отдаются из кэша")
  func hit() {
    var cache = AccentCache(capacity: 2)
    #expect(cache.lookup("a", artwork: Self.artwork) == .miss)
    cache.store("a", colors: Self.red, artwork: Self.artwork)
    #expect(cache.lookup("a", artwork: Self.artwork) == .hit(Self.red))
  }

  @Test("Неудача на той же обложке запоминается, на новой обложке — считаем заново")
  func failure() {
    var cache = AccentCache(capacity: 2)
    cache.store("a", colors: nil, artwork: Self.artwork)
    #expect(cache.lookup("a", artwork: Self.artwork) == .knownFailure)
    #expect(cache.lookup("a", artwork: Data([9])) == .miss)
    #expect(cache.lookup("a", artwork: nil) == .miss)
  }

  @Test("Кэш не растёт сверх ёмкости: вытесняется давно не нужный трек")
  func evictsLeastRecent() {
    var cache = AccentCache(capacity: 2)
    cache.store("a", colors: Self.red, artwork: Self.artwork)
    cache.store("b", colors: Self.red, artwork: Self.artwork)
    // обращение к «a» делает его свежим, вытеснится «b»
    _ = cache.lookup("a", artwork: Self.artwork)
    cache.store("c", colors: Self.red, artwork: Self.artwork)
    #expect(cache.count == 2)
    #expect(cache.lookup("a", artwork: Self.artwork) == .hit(Self.red))
    #expect(cache.lookup("b", artwork: Self.artwork) == .miss)
    #expect(cache.lookup("c", artwork: Self.artwork) == .hit(Self.red))
  }
}
