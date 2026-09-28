import IslandCore
import SwiftUI

/// Остров целиком: форма и контент по состоянию. Размер окна фиксированный, анимируется только форма
public struct IslandView: View {
    let model: IslandModel
    let spec: IslandShapeSpec
    let notchWidth: CGFloat
    let nowPlaying: NowPlayingInfo?
    let agenda: DayAgenda
    let calendarEvent: CalendarEvent?
    let onClick: () -> Void
    let onAction: (PlayerAction) -> Void
    let onJoin: (URL) -> Void

    public init(
        model: IslandModel, spec: IslandShapeSpec, notchWidth: CGFloat, nowPlaying: NowPlayingInfo?,
        agenda: DayAgenda = .empty,
        calendarEvent: CalendarEvent? = nil,
        onClick: @escaping () -> Void, onAction: @escaping (PlayerAction) -> Void,
        onJoin: @escaping (URL) -> Void = { _ in }
    ) {
        self.model = model
        self.spec = spec
        self.notchWidth = notchWidth
        self.nowPlaying = nowPlaying
        self.agenda = agenda
        self.calendarEvent = calendarEvent
        self.onClick = onClick
        self.onAction = onAction
        self.onJoin = onJoin
    }

    public var body: some View {
        ZStack(alignment: .top) {
            IslandShape(spec: spec)
                .fill(IslandPalette.background)
                // тень только у раскрытого: меняется вместе с моделью внутри withAnimation и растёт той же пружиной
                .shadow(
                    color: .black.opacity(model.surface == .expanded ? IslandGeometry.Shadow.opacity : 0),
                    radius: IslandGeometry.Shadow.radius,
                    y: IslandGeometry.Shadow.y)
            content
                .modifier(OpenScale(size: spec.size, target: spec.size, scalesContent: model.surface == .expanded))
                .clipShape(IslandShape(spec: spec, shoulder: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(IslandShape(spec: spec))
        .onTapGesture(perform: onClick)
    }

    @ViewBuilder
    private var content: some View {
        switch model.surface {
        // отклик на hover в той же ветке: вью музыки не пересоздаётся и не играет переход
        case .compact, .peek, .hoverNudge(from: .compact), .hoverNudge(from: .peek):
            MusicLiveView(info: nowPlaying, notchWidth: notchWidth, showsTitle: liveSurface == .peek)
                // рамка итогового размера, а не текущей формы: обложка и волна стоят на своих местах
                // и открываются маской формы, а не едут вместе с её краями. Уходящий вью держит свою рамку.
                // В отклике рамка исходного состояния: форма расширяется вокруг контента, он не сдвигается
                .frame(width: liveSize.width, height: liveSize.height, alignment: .top)
                .id(ContentID.music)
                .transition(.slot)
        case .calendar, .calendarPeek, .hoverNudge(from: .calendar), .hoverNudge(from: .calendarPeek):
            CalendarLiveView(event: calendarEvent, showsLine: liveSurface == .calendarPeek, notchWidth: notchWidth)
                // как у музыки: рамка итогового размера, контент открывается маской формы
                .frame(width: liveSize.width, height: liveSize.height, alignment: .top)
                .id(ContentID.calendar)
                .transition(.slot)
        case .expanded:
            // раскрытый открывается в Duo, как в Alcove (решение 27.09). Плеер и календарь — листанием (ui-inspection 3.7)
            ExpandedContent(view: model.expandedView, info: nowPlaying, agenda: agenda, onAction: onAction, onJoin: onJoin,
                            timeScale: model.config.timeScale)
                .id(ContentID.expanded)
                .transition(.playerEntrance(timeScale: model.config.timeScale))
        case let .hud(kind, level):
            HUDView(kind: kind, level: level, notchWidth: notchWidth)
                // как у музыки: в узкой рамке растущей формы подпись переносилась на две строки
                .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
                .id(ContentID.hud(kind))
                .transition(.slot)
        case let .alert(alert):
            AlertView(alert: alert, notchWidth: notchWidth)
                // как у HUD: рамка текущей формы, контент разъезжается вместе с краями
                .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
                .id(ContentID.alert)
                .transition(.slot)
        case .idle, .hover, .shrink, .hoverNudge:
            Color.clear
        }
    }

    /// Ширина самого широкого индикатора компакта календаря: по ней считается фиксированная ширина
    /// компакта и peek (IslandGeometry.calendarSize). Store берёт её же, чтобы форма и рамка контента совпали
    public nonisolated static let calendarIndicatorWidth =
        ActivityCompactView.indicatorWidth(ActivityLayouts.calendarWidestIndicator)

    /// Ширина «15m», самого широкого индикатора напоминания: пол ширины напоминания
    /// (IslandGeometry.size(for:notch:reminderIndicatorWidth:)). Store берёт её же, как calendarIndicatorWidth
    public nonisolated static let reminderIndicatorWidth =
        ActivityCompactView.indicatorWidth(ActivityLayouts.reminderWidestIndicator)

    /// Состояние, по которому раскладывается живая активность (музыка, календарь): для отклика — то,
    /// из которого он открылся
    private var liveSurface: Surface {
        if case let .hoverNudge(from) = model.surface { return from }
        return model.surface
    }

    private var liveSize: CGSize {
        let notch = CGSize(width: notchWidth, height: spec.size.height)
        return IslandGeometry.spec(
            for: liveSurface, hasMedia: model.hasMedia, notch: notch, calendarIndicatorWidth: Self.calendarIndicatorWidth,
            reminderIndicatorWidth: Self.reminderIndicatorWidth
        ).size
    }

    private enum ContentID: Hashable {
        case music, expanded
        case calendar
        case hud(HUDKind)
        case alert
    }
}
