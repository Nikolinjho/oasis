import Foundation

/// Ссылка на созвон в событии календаря: Google Meet, Zoom, Яндекс Телемост, Microsoft Teams (решение 27.09)
public enum MeetingLink {
    static let hosts = [
        "meet.google.com", "zoom.us", "zoom.com", "zoomgov.com", "telemost.yandex.ru", "telemost.360.yandex.ru",
        "teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft",
    ]

    /// Ищет по порядку в поле URL, месте и заметках. Первая ссылка на созвон выигрывает
    public static func find(in event: CalendarEvent) -> URL? {
        for text in [event.url?.absoluteString, event.location, event.notes].compactMap({ $0 }) {
            if let url = firstMeeting(in: text) { return url }
        }
        return nil
    }

    static func firstMeeting(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url,
                // только http/https: file://, smb://, vnc://, zoommtg:// и другие схемы с подставленным
                // разрешённым хостом не должны открывать локальные приложения или сетевые шары
                let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                let host = url.host()?.lowercased()
            else { continue }
            if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
        }
        return nil
    }
}
