/// Now Playing → Source (ui-inspection 1.8). Сейчас источник один — MediaRemote через адаптер, у Alcove это System.
/// Заготовка под свои источники (решение 28.09): Яндекс Музыка придёт своим NowPlayingSource, до тех пор — Soon
public enum MediaSourceChoice: String, CaseIterable, Sendable {
    case system
    case yandexMusic

    public var title: String {
        switch self {
        case .system: "System"
        case .yandexMusic: "Yandex Music"
        }
    }

    public var isAvailable: Bool { self == .system }
}
