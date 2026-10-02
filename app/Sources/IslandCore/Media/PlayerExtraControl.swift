/// Now Playing → доп. кнопка слева в плеере (ui-inspection 1.8; Alcove 1.7.9: плитки Favorite, Shuffle, Repeat,
/// Copy, по умолчанию Shuffle — controlChoice = shuffle в UserDefaults Alcove)
public enum PlayerExtraControl: String, CaseIterable, Sendable {
  case favorite, shuffle, `repeat`, copy

  public var title: String {
    switch self {
    case .favorite: "Favorite"
    case .shuffle: "Shuffle"
    case .repeat: "Repeat"
    case .copy: "Copy"
    }
  }

  /// Copy у Alcove копирует ссылку на трек. Ссылки не отдаёт ни один наш источник: плитка Soon
  public var isAvailable: Bool { self != .copy }
}
