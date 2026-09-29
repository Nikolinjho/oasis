import IslandCore
import SwiftUI

/// Форматтеры даты и времени Duo, по одному общему инстансу на формат вместо создания в каждом вызове.
/// Locale всегда en_US_POSIX: день недели капсом и время в 12-часовом формате как в самом Alcove,
/// а не локаль системы пользователя. calendar/timeZone выставляются на месте перед каждым форматированием —
/// у тестов и live-острова разные календари, а DateFormatter один на процесс.
/// DateFormatter — Sendable, static let без nonisolated(unsafe) достаточно
private enum DuoFormatters {
    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

/// Раскладка Duo по AX-фреймам нативного Alcove (ui-inspection 3.3): тело x 691.5…1036.5,
/// координаты здесь — от левого верхнего угла тела 345×175
enum DuoLayout {
    static let size = CGSize(width: 345, height: 175)
    /// Обложка 55 по ширине, от края тела 17.5, центр по y 45.5 (AX Alcove 1.7.9: 55×55 у Music, 54×30 у YouTube,
    /// 28.09 и 29.09). Прежние 45 — рамка на паузе из осмотра 1.7.7: 54 × 0.83
    static let artworkSide: CGFloat = 55
    static let artworkX: CGFloat = 17.5
    static let artworkCenterY: CGFloat = 45.5
    static let titleOrigin = CGPoint(x: 17.5, y: 75)
    static let titleSize = CGSize(width: 138, height: 40)
    static let controlsY: CGFloat = 121
    static let controlXs: [CGFloat] = [20.5, 65.5, 109.5]
    static let controlSize = CGSize(width: 42, height: 40)
    static let dividerX: CGFloat = 172.5
    static let dividerTop: CGFloat = 50
    static let dividerBottom: CGFloat = 157
    /// AX-кнопка даты 40×50 у правого края. Число «26» шире 40 pt, поэтому рамка шире и прижата вправо
    static let dateFrame = CGRect(x: 286.5, y: 18, width: 40, height: 50)
    static let dateWidth: CGFloat = 70
    static let eventOrigin = CGPoint(x: 188.5, y: 72)
    static let emptyOrigin = CGPoint(x: 188.5, y: 92)

    /// Карточка события: 138 в ширину, 28 без места и 40 с местом, между карточками 4 (AX Alcove 1.7.9, 29.09)
    static let eventWidth: CGFloat = 138
    static let eventSpacing: CGFloat = 4
    /// Низ колонки событий — низ разделителя. Сколько карточек влезает у Alcove, не проверяли: оценка
    static let eventColumnBottom: CGFloat = dividerBottom

    /// Сколько карточек стопки помещается целиком от eventOrigin.y до eventColumnBottom
    static func fitting(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var used: CGFloat = 0
        var result: [CalendarEvent] = []
        for event in events {
            let height = EventCard.height(for: event) + (result.isEmpty ? 0 : eventSpacing)
            guard used + height <= eventColumnBottom - eventOrigin.y else { break }
            used += height
            result.append(event)
        }
        return result
    }
}

/// Название бегущей строкой и артист под ним
struct DuoTitle: View {
    let info: NowPlayingInfo?
    /// Показанное название (Hide media title extras чистит его снаружи через appearance.title(for:)).
    /// info.title остаётся исходным по умолчанию: трогать его самого не нужно, trackKey от него не зависит здесь
    var title: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            MarqueeText(text: title ?? info?.title ?? "Not Playing", shortAlignment: .leading, outdentsFade: true)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IslandPalette.foreground)
                .frame(height: 18)
            Text(info?.artist ?? "")
                .font(.system(size: 13))
                .foregroundStyle(IslandPalette.secondary)
                .lineLimit(1)
        }
    }
}

/// Кнопки Duo: ⏪ ▶ ⏩ по 42×40 (ui-inspection 3.3)
struct DuoControl: Equatable {
    let symbol: String
    let action: PlayerAction
    /// Play крупнее перемоток. Размеры по пропорциям кадра, замера нет
    let size: CGFloat
    var isEnabled = true

    var highlightsOnHover: Bool { action == .media(.togglePlayPause) }

    static func row(_ info: NowPlayingInfo?) -> [DuoControl] {
        let canSkip = info?.canSkip ?? true
        return [
            DuoControl(symbol: "backward.fill", action: .media(.previousTrack), size: 18, isEnabled: canSkip),
            DuoControl(
                symbol: info?.isPlaying == true ? "pause.fill" : "play.fill",
                action: .media(.togglePlayPause), size: 24),
            DuoControl(symbol: "forward.fill", action: .media(.nextTrack), size: 18, isEnabled: canSkip),
        ]
    }
}

struct DuoControlButton: View {
    let control: DuoControl
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: control.symbol)
                .font(.system(size: control.size, weight: .semibold))
                .foregroundStyle(control.isEnabled ? IslandPalette.foreground : IslandPalette.tertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: DuoLayout.controlSize.width, height: DuoLayout.controlSize.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(DuoControlStyle(isHovered: isHovered && control.highlightsOnHover))
        .onHover { isHovered = $0 }
        .disabled(!control.isEnabled)
    }
}

/// Подложка ~36×36 с радиусом ~10 под курсором, при нажатии чуть светлее и иконка меньше на ~10%
struct DuoControlStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill(isPressed: configuration.isPressed))
                    .frame(width: 36, height: 36))
            // замера нет, оценка: как у кнопок плеера
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private func fill(isPressed: Bool) -> Color {
        if isPressed { return IslandPalette.pressedActive }
        return isHovered ? IslandPalette.duoHover : .clear
    }
}

/// «SAT» красным 10 pt жирным капсом, под ним «26» ~34 pt тонким белым, выравнивание вправо
struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(alignment: .trailing, spacing: -3) {
            Text(Self.weekday(date))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(IslandPalette.dateAccent)
            Text(Self.day(date))
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(IslandPalette.foreground)
        }
    }

    nonisolated static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DuoFormatters.weekday
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date).uppercased()
    }

    nonisolated static func day(_ date: Date, calendar: Calendar = .current) -> String {
        String(calendar.component(.day, from: date))
    }
}

/// Карточка события: полупрозрачный фон и полоска в цвете календаря, название и время тем же цветом.
/// 138×28 без места (название + время), 138×40 с местом (название + 📍место + время, Alcove 1.7.9, 29.09)
struct EventCard: View {
    let event: CalendarEvent
    var onJoin: (() -> Void)? = nil

    var body: some View {
        let color = Color(event.color)
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let location = Self.location(event) {
                    // булавка и место, как на кадре duo-event-location.jpg; кегль — как у времени, оценка
                    Label {
                        Text(location).lineLimit(1).truncationMode(.tail)
                    } icon: {
                        Image(systemName: "mappin").font(.system(size: 8, weight: .semibold))
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
                }
                Text(Self.timeRange(event))
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
                    .lineLimit(1)
            }
            .foregroundStyle(color)
            Spacer(minLength: 0)
            if let onJoin {
                // у Alcove Join — в контекстном меню, у нас кнопка на карточке (решение 27.09)
                Button(action: onJoin) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(IslandPalette.background)
                        .frame(width: 22, height: 18)
                        .background(Capsule().fill(color))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
                .help("Join")
            }
        }
        // отступы и прозрачность фона не мерили, оценка по кадру duo-event.jpg
        .padding(.vertical, 3)
        .padding(.leading, 4)
        .frame(width: DuoLayout.eventWidth, height: Self.height(for: event))
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(0.15)))
    }

    nonisolated static func timeRange(_ event: CalendarEvent, calendar: Calendar = .current) -> String {
        let formatter = DuoFormatters.time
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return "\(formatter.string(from: event.start)) – \(formatter.string(from: event.end))"
    }

    /// Место без пробельных строк: пустое место у EventKit — не место
    nonisolated static func location(_ event: CalendarEvent) -> String? {
        guard let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty else {
            return nil
        }
        return location
    }

    nonisolated static func height(for event: CalendarEvent) -> CGFloat {
        location(event) == nil ? 28 : 40
    }
}

/// Событий больше нет: две строки серым, вторая темнее
struct EmptyDay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("No more events today")
                .foregroundStyle(IslandPalette.secondary)
                .frame(height: 16, alignment: .leading)
            Text("Your day is clear")
                .foregroundStyle(IslandPalette.tertiary)
                .frame(height: 16, alignment: .leading)
        }
        .font(.system(size: 11, weight: .semibold))
    }
}
