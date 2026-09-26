import AppKit
import IslandCore
import SwiftUI
import Testing
@testable import IslandUI

struct MusicViewTests {
    static let artwork: Data = {
        let image = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSColor(srgbRed: 0.95, green: 0.45, blue: 0.1, alpha: 1).setFill()
            rect.fill()
            return true
        }
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }()

    static let info = NowPlayingInfo(
        title: "Fire in the Hole of the Long Title", artist: "Demo Artist", isPlaying: true,
        duration: 200, elapsed: 61.9, artwork: artwork, accent: RGB(red: 0.95, green: 0.45, blue: 0.1))

    @Test("Строка peek: название и артист")
    func titleLine() {
        #expect(MusicLiveView.titleLine(NowPlayingInfo(title: "Fire", artist: "A", isPlaying: true)) == "♪ Fire ∙ A")
        #expect(MusicLiveView.titleLine(NowPlayingInfo(title: "Fire", isPlaying: true)) == "♪ Fire")
        #expect(MusicLiveView.titleLine(NowPlayingInfo(title: "Fire", artist: "", isPlaying: true)) == "♪ Fire")
        #expect(MusicLiveView.titleLine(nil) == "")
    }

    @Test("Время в минутах и секундах")
    func timeFormat() {
        #expect(ProgressRow.format(0) == "0:00")
        #expect(ProgressRow.format(61.9) == "1:01")
        #expect(ProgressRow.format(3600) == "60:00")
    }

    @Test("Оставшееся время со знаком минус")
    func remainingFormat() {
        #expect(ProgressRow.remaining(position: 9, duration: 223) == "-3:34")
        // 1:01 слева и -2:19 справа в сумме дают 3:20
        #expect(ProgressRow.remaining(position: 61.9, duration: 200) == "-2:19")
        #expect(ProgressRow.remaining(position: 0, duration: 0) == "-0:00")
        // позиция за концом трека не даёт отрицательного остатка
        #expect(ProgressRow.remaining(position: 250, duration: 200) == "-0:00")
    }

    @MainActor
    @Test("Снимки компакта, peek и плеера")
    func snapshots() throws {
        let island = { (size: CGSize, content: AnyView) in
            ZStack(alignment: .top) {
                IslandShape(spec: IslandShapeSpec(size: size, bottomRadius: IslandGeometry.bottomRadius(forHeight: size.height)), shoulder: 0)
                    .fill(IslandPalette.background)
                content
            }
        }
        #expect(try Snapshot.write(
            island(IslandGeometry.compact, AnyView(MusicLiveView(info: Self.info, notchWidth: 186, showsTitle: false))),
            size: IslandGeometry.compact, name: "music-compact") == CGSize(width: 514, height: 64))
        #expect(try Snapshot.write(
            island(IslandGeometry.peek, AnyView(MusicLiveView(info: Self.info, notchWidth: 186, showsTitle: true))),
            size: IslandGeometry.peek, name: "music-peek") == CGSize(width: 552, height: 102))
        #expect(try Snapshot.write(
            island(IslandGeometry.expanded, AnyView(PlayerView(info: Self.info, onAction: { _ in }))),
            size: IslandGeometry.expanded, name: "player") == CGSize(width: 690, height: 350))
        var paused = Self.info
        paused.isPlaying = false
        try Snapshot.write(
            island(IslandGeometry.expanded, AnyView(PlayerView(info: paused, onAction: { _ in }))),
            size: IslandGeometry.expanded, name: "player-paused")
    }
}
