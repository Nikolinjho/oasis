/// General → Display on: главный экран (с menu bar) или конкретный по имени.
/// All displays сознательно нет: решение пользователя 27.09
public enum DisplayChoice: Hashable, Sendable {
    case main
    /// NSScreen.localizedName: id экрана меняется при переподключении, имя — нет
    case named(String)

    public var storageValue: String {
        switch self {
        case .main: "main"
        case let .named(name): "screen:" + name
        }
    }

    public init(storageValue: String?) {
        guard let value = storageValue, value.hasPrefix("screen:"), value.count > 7 else {
            self = .main
            return
        }
        self = .named(String(value.dropFirst(7)))
    }
}
