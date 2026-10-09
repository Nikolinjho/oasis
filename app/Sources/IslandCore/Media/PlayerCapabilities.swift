/// Команды и циклы режимов, доступные в текущем контексте источника
public struct PlayerCapabilities: Equatable, Sendable {
  public var canPlayPause: Bool
  public var canNext: Bool
  public var canPrevious: Bool
  public var canSeek: Bool
  public var canFavorite: Bool
  public var shuffleModes: [Int]
  public var repeatModes: [Int]
  /// Источник должен подтвердить режим, даже если пока не прислал его значение
  public var requiresConfirmation: Bool

  public init(
    canPlayPause: Bool, canNext: Bool, canPrevious: Bool, canSeek: Bool,
    canFavorite: Bool, shuffleModes: [Int], repeatModes: [Int], requiresConfirmation: Bool = false
  ) {
    self.canPlayPause = canPlayPause
    self.canNext = canNext
    self.canPrevious = canPrevious
    self.canSeek = canSeek
    self.canFavorite = canFavorite
    self.shuffleModes = shuffleModes
    self.repeatModes = repeatModes
    self.requiresConfirmation = requiresConfirmation
  }
}
