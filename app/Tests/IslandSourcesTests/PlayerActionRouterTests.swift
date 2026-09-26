import IslandCore
import Testing
@testable import IslandSources

/// Записывает, какой исполнитель и с чем вызван
@MainActor
final class FakePerformer: PlayerActionPerforming {
    enum Call: Equatable {
        case media(MediaCommand)
        case favorite
        case activate(String)
        case chooseOutput
    }

    private(set) var calls: [Call] = []

    func send(_ command: MediaCommand) { calls.append(.media(command)) }
    func favoriteInMusic() { calls.append(.favorite) }
    func activateApp(bundleID: String) { calls.append(.activate(bundleID)) }
    func chooseOutput() { calls.append(.chooseOutput) }
}

@MainActor
struct PlayerActionRouterTests {
    static func track(_ bundleID: String?) -> NowPlayingInfo {
        NowPlayingInfo(bundleID: bundleID, title: "Water", isPlaying: true)
    }

    @Test("Медиакоманда уходит в плеер как есть")
    func media() {
        let fake = FakePerformer()
        let router = PlayerActionRouter(performer: fake)
        router.perform(.media(.nextTrack), nowPlaying: Self.track("com.apple.Music"))
        router.perform(.media(.togglePlayPause), nowPlaying: nil)
        #expect(fake.calls == [.media(.nextTrack), .media(.togglePlayPause)])
    }

    @Test("Избранное — только когда играет Apple Music")
    func favoriteInMusic() {
        let fake = FakePerformer()
        PlayerActionRouter(performer: fake).perform(.favorite, nowPlaying: Self.track("com.apple.Music"))
        #expect(fake.calls == [.favorite])
    }

    @Test("Избранное у другого источника или без трека не трогает Music")
    func favoriteElsewhere() {
        let fake = FakePerformer()
        let router = PlayerActionRouter(performer: fake)
        router.perform(.favorite, nowPlaying: Self.track("com.spotify.client"))
        router.perform(.favorite, nowPlaying: Self.track(nil))
        router.perform(.favorite, nowPlaying: nil)
        #expect(fake.calls.isEmpty)
    }

    @Test("Открыть источник — приложение по bundleID текущего трека")
    func openSource() {
        let fake = FakePerformer()
        PlayerActionRouter(performer: fake).perform(.openSource, nowPlaying: Self.track("com.google.Chrome"))
        #expect(fake.calls == [.activate("com.google.Chrome")])
    }

    @Test("Без bundleID открывать нечего")
    func openSourceUnknown() {
        let fake = FakePerformer()
        let router = PlayerActionRouter(performer: fake)
        router.perform(.openSource, nowPlaying: Self.track(nil))
        router.perform(.openSource, nowPlaying: nil)
        #expect(fake.calls.isEmpty)
    }

    @Test("Выбор выхода не зависит от трека")
    func chooseOutput() {
        let fake = FakePerformer()
        PlayerActionRouter(performer: fake).perform(.chooseOutput, nowPlaying: nil)
        #expect(fake.calls == [.chooseOutput])
    }
}
