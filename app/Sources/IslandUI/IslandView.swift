import IslandCore
import SwiftUI

/// Остров целиком: форма и контент по состоянию. Размер окна фиксированный, анимируется только форма
public struct IslandView: View {
    let model: IslandModel
    let spec: IslandShapeSpec
    let notchWidth: CGFloat
    let nowPlaying: NowPlayingInfo?
    let onClick: () -> Void
    let onCommand: (MediaCommand) -> Void

    public init(
        model: IslandModel, spec: IslandShapeSpec, notchWidth: CGFloat, nowPlaying: NowPlayingInfo?,
        onClick: @escaping () -> Void, onCommand: @escaping (MediaCommand) -> Void
    ) {
        self.model = model
        self.spec = spec
        self.notchWidth = notchWidth
        self.nowPlaying = nowPlaying
        self.onClick = onClick
        self.onCommand = onCommand
    }

    public var body: some View {
        ZStack(alignment: .top) {
            IslandShape(spec: spec).fill(IslandPalette.background)
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
                .id(ContentID.music)
                .transition(.slot)
        case .expanded:
            PlayerView(info: nowPlaying, onCommand: onCommand)
                .id(ContentID.player)
                .transition(.playerEntrance(timeScale: model.config.timeScale))
        case let .hud(kind, level):
            HUDView(kind: kind, level: level, notchWidth: notchWidth)
                .id(ContentID.hud(kind))
                .transition(.slot)
        case .idle, .hover, .shrink:
            Color.clear
        }
    }

    private enum ContentID: Hashable {
        case music, player
        case hud(HUDKind)
    }
}
