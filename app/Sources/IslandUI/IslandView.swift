import IslandCore
import SwiftUI

/// Остров целиком: форма и контент по состоянию. Размер окна фиксированный, анимируется только форма
public struct IslandView: View {
    let model: IslandModel
    let spec: IslandShapeSpec
    let notchWidth: CGFloat
    let nowPlaying: NowPlayingInfo?
    let agenda: DayAgenda
    let onClick: () -> Void
    let onAction: (PlayerAction) -> Void

    public init(
        model: IslandModel, spec: IslandShapeSpec, notchWidth: CGFloat, nowPlaying: NowPlayingInfo?,
        agenda: DayAgenda = .empty,
        onClick: @escaping () -> Void, onAction: @escaping (PlayerAction) -> Void
    ) {
        self.model = model
        self.spec = spec
        self.notchWidth = notchWidth
        self.nowPlaying = nowPlaying
        self.agenda = agenda
        self.onClick = onClick
        self.onAction = onAction
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
            MusicLiveView(info: nowPlaying, notchWidth: notchWidth, showsTitle: musicSurface == .peek)
                // рамка итогового размера, а не текущей формы: обложка и волна стоят на своих местах
                // и открываются маской формы, а не едут вместе с её краями. Уходящий вью держит свою рамку.
                // В отклике рамка исходного состояния: форма расширяется вокруг контента, он не сдвигается
                .frame(width: musicSize.width, height: musicSize.height, alignment: .top)
                .id(ContentID.music)
                .transition(.slot)
        case .expanded:
            // раскрытый по умолчанию — Duo, как в Alcove (решение 27.09). Полный плеер — свайпом, P1
            DuoView(info: nowPlaying, agenda: agenda, onAction: onAction)
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

    /// Состояние, по которому раскладывается музыка: для отклика — то, из которого он открылся
    private var musicSurface: Surface {
        if case let .hoverNudge(from) = model.surface { return from }
        return model.surface
    }

    private var musicSize: CGSize {
        let notch = CGSize(width: notchWidth, height: spec.size.height)
        return IslandGeometry.spec(for: musicSurface, hasMedia: model.hasMedia, notch: notch).size
    }

    private enum ContentID: Hashable {
        case music, expanded
        case hud(HUDKind)
        case alert
    }
}
