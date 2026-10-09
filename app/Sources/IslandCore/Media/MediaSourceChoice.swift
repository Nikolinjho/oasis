/// Ручной выбор источника Now Playing: системный адаптер или Яндекс Музыка
public enum MediaSourceChoice: String, CaseIterable, Sendable {
  case system
  case yandexMusic

  public var title: String {
    switch self {
    case .system: "System"
    case .yandexMusic: "Yandex Music"
    }
  }

  public var isAvailable: Bool { true }
}
