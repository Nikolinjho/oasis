import IslandCore
import SwiftUI

/// Смена трека: старая обложка поворачивается до ребра, на ребре подменяется размытой новой,
/// та доворачивается и проявляется (capture/analysis/README.md, «Смена трека: 3D-переворот обложки»)
struct ArtworkFlip: View {
    let info: NowPlayingInfo?
    let side: CGFloat
    let radius: CGFloat
    /// false — Disable artwork flip: новая обложка сразу, без поворота
    var flips = true

    /// Уходящий трек до ребра. После ребра рисуется живой info, поэтому поздняя обложка не теряется
    @State private var outgoing: NowPlayingInfo?
    @State private var flipTask: Task<Void, Never>?
    @State private var angle: Double = 0
    @State private var blur: CGFloat = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        ArtworkView(artwork: (outgoing ?? info)?.artwork, side: side, radius: radius)
            .blur(radius: blur)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .onChange(of: info) { old, new in
                if old?.trackKey != new?.trackKey { flip(from: old) }
            }
            .onDisappear { flipTask?.cancel() }
    }

    private func flip(from old: NowPlayingInfo?) {
        // первый трек появляется без переворота
        guard let old else { return }
        // Disable artwork flip: новая обложка сразу, без поворота
        guard flips else { return }
        // прошлый переворот ещё не долистал до угла 0: трек скипнули быстро — не копим по 130 мс на каждый
        // такой скип, иначе при частой перемотке обложка дольше обычного простаивает на ребре
        let alreadyFlipping = angle != 0 || outgoing != nil
        flipTask?.cancel()
        // переворот ещё не дошёл до ребра: на экране по-прежнему прежний outgoing
        if outgoing == nil { outgoing = old }
        flipTask = Task { @MainActor in
            if !alreadyFlipping {
                // название уже сменилось, обложка ждёт ~130 мс (запись Alcove №2)
                try? await Task.sleep(for: IslandTiming.artworkFlipDelay)
                guard !Task.isCancelled else { return }
            }
            withAnimation(.easeIn(duration: 0.12)) { angle = 90 }
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            outgoing = nil
            angle = -90
            // замера нет, оценка; вероятно, снято на большой обложке плеера
            blur = 20
            // замера нет, оценка
            scale = 1.08
            // замера нет, оценка: доворот 0.13 с
            withAnimation(.easeOut(duration: 0.13)) { angle = 0 }
            withAnimation(.easeOut(duration: 0.4)) {
                blur = 0
                scale = 1
            }
        }
    }
}
