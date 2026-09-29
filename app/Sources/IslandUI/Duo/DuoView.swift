import IslandCore
import SwiftUI

/// Раскрытый Duo 345×175: плеер слева, дата и ближайшее событие справа (ui-inspection 3.3).
/// Элементы стоят по AX-фреймам нативного Alcove. now задают тесты, в приложении — раз в минуту
struct DuoView: View {
    let info: NowPlayingInfo?
    let agenda: DayAgenda
    var appearance = IslandAppearance.default
    /// Событие открытого окна календаря: карточка и Join — о нём, как компакт и меню (DayAgenda.current)
    var liveEvent: CalendarEvent? = nil
    var now: Date? = nil
    var onJoin: (URL) -> Void = { _ in }
    let onAction: (PlayerAction) -> Void

    var body: some View {
        if let now {
            content(now)
        } else {
            TimelineView(.everyMinute) { context in content(context.date) }
        }
    }

    private func content(_ now: Date) -> some View {
        ZStack(alignment: .topLeading) {
            ArtworkFlip(info: info, side: DuoLayout.artworkSide, radius: 6, flips: appearance.artworkFlip)
                .modifier(PausedArtwork(isPlaying: info?.isPlaying ?? false))
                .offset(x: DuoLayout.artworkX, y: DuoLayout.artworkCenterY - DuoLayout.artworkSide / 2)
            DuoTitle(info: info, title: appearance.title(for: info))
                .frame(width: DuoLayout.titleSize.width, height: DuoLayout.titleSize.height, alignment: .topLeading)
                .offset(x: DuoLayout.titleOrigin.x, y: DuoLayout.titleOrigin.y)
            // id по месту в ряду: смена ⏸/▶ не пересоздаёт кнопку
            ForEach(Array(DuoControl.row(info).enumerated()), id: \.offset) { index, control in
                DuoControlButton(control: control) { onAction(control.action) }
                    .offset(x: DuoLayout.controlXs[index], y: DuoLayout.controlsY)
            }
            Rectangle()
                .fill(IslandPalette.divider)
                .frame(width: 1, height: DuoLayout.dividerBottom - DuoLayout.dividerTop)
                .offset(x: DuoLayout.dividerX - 0.5, y: DuoLayout.dividerTop)
            DateBadge(date: now)
                .frame(width: DuoLayout.dateWidth, height: DuoLayout.dateFrame.height, alignment: .topTrailing)
                .offset(x: DuoLayout.dateFrame.maxX - DuoLayout.dateWidth, y: DuoLayout.dateFrame.minY)
            if let event = agenda.current(at: now, live: liveEvent) {
                EventCard(event: event, onJoin: MeetingLink.find(in: event).map { url in { onJoin(url) } })
                    .offset(x: DuoLayout.eventOrigin.x, y: DuoLayout.eventOrigin.y)
            } else {
                EmptyDay()
                    .offset(x: DuoLayout.emptyOrigin.x, y: DuoLayout.emptyOrigin.y)
            }
        }
        .frame(width: DuoLayout.size.width, height: DuoLayout.size.height, alignment: .topLeading)
    }
}
