import IslandCore
import SwiftUI

/// Остров целиком: форма и контент по состоянию. Размер окна фиксированный, анимируется только форма
public struct IslandView: View {
    let model: IslandModel
    let spec: IslandShapeSpec
    let notchWidth: CGFloat
    let nowPlaying: NowPlayingInfo?
    let onClick: () -> Void
    let onAction: (PlayerAction) -> Void

    public init(
        model: IslandModel, spec: IslandShapeSpec, notchWidth: CGFloat, nowPlaying: NowPlayingInfo?,
        onClick: @escaping () -> Void, onAction: @escaping (PlayerAction) -> Void
    ) {
        self.model = model
        self.spec = spec
        self.notchWidth = notchWidth
        self.nowPlaying = nowPlaying
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
        case .compact, .peek:
            MusicLiveView(info: nowPlaying, notchWidth: notchWidth, showsTitle: model.surface == .peek)
                // рамка итогового размера, а не текущей формы: обложка и волна стоят на своих местах
                // и открываются маской формы, а не едут вместе с её краями. Уходящий вью держит свою рамку
                .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
                .id(ContentID.music)
                .transition(.slot)
        case .expanded:
            PlayerView(info: nowPlaying, onAction: onAction)
                .id(ContentID.player)
                .transition(.playerEntrance(timeScale: model.config.timeScale))
        case let .hud(kind, level):
            HUDView(kind: kind, level: level, notchWidth: notchWidth)
                // как у музыки: в узкой рамке растущей формы подпись переносилась на две строки
                .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
                .id(ContentID.hud(kind))
                .transition(.slot)
        case .idle, .hover, .shrink, .hoverNudge:
            Color.clear
        }
    }

    private enum ContentID: Hashable {
        case music, player
        case hud(HUDKind)
    }
}
