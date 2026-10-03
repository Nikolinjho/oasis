import Foundation
import IslandCore

/// Цвета обложек по trackKey. Ограничен по размеру: за долгую сессию треков набегают тысячи, а нужен
/// по сути только текущий (и пара соседних, если пользователь переключается туда-обратно)
struct AccentCache {
  struct Colors: Equatable {
    var accent: RGB
    var bottom: RGB?
  }

  enum Lookup: Equatable {
    case hit(Colors)
    /// Эта же обложка уже не посчиталась: не тратим decode повторно на каждой строке адаптера
    case knownFailure
    case miss
  }

  private enum Entry {
    case colors(Colors)
    /// Помним саму обложку: если у трека она сменится (браузер дослал настоящую), посчитаем заново
    case failed(Data)
  }

  let capacity: Int
  private var entries: [String: Entry] = [:]
  /// Ключи от давно не нужных к свежим
  private var order: [String] = []

  init(capacity: Int = 16) {
    self.capacity = max(capacity, 1)
  }

  var count: Int { entries.count }

  mutating func lookup(_ key: String, artwork: Data?) -> Lookup {
    guard let entry = entries[key] else { return .miss }
    touch(key)
    switch entry {
    case .colors(let colors): return .hit(colors)
    case .failed(let failed): return failed == artwork ? .knownFailure : .miss
    }
  }

  /// colors == nil — расчёт по artwork не удался
  mutating func store(_ key: String, colors: Colors?, artwork: Data) {
    entries[key] = colors.map(Entry.colors) ?? .failed(artwork)
    touch(key)
    while order.count > capacity {
      entries[order.removeFirst()] = nil
    }
  }

  private mutating func touch(_ key: String) {
    order.removeAll { $0 == key }
    order.append(key)
  }
}
