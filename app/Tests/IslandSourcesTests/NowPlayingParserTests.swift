import Foundation
import IslandCore
import Testing
@testable import IslandSources

struct NowPlayingParserTests {
    static let lines: [String] = {
        let url = Bundle.module.url(forResource: "stream", withExtension: "jsonl", subdirectory: "Fixtures")!
        return try! String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }()
    static let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("Первый трек — newTrack со всеми полями в секундах")
    func firstLine() throws {
        var parser = NowPlayingParser()
        let change = parser.consume(Self.lines[0], now: Self.now)
        guard case let .newTrack(info)? = change else { Issue.record("ожидали newTrack, пришло \(String(describing: change))"); return }
        #expect(info.title == "Fire")
        #expect(info.artist == "Artist A")
        #expect(info.album == "Album A")
        #expect(info.bundleID == "com.google.Chrome")
        #expect(info.isPlaying)
        #expect(info.duration == 240)
        #expect(info.elapsed == 60)
        #expect(info.elapsedAt == Self.now)
        #expect(info.artwork?.count == 8)
    }

    @Test("Тот же трек на паузе — updated")
    func samePausedTrack() {
        var parser = NowPlayingParser()
        _ = parser.consume(Self.lines[0], now: Self.now)
        guard case let .updated(info)? = parser.consume(Self.lines[1], now: Self.now) else { Issue.record("ожидали updated"); return }
        #expect(!info.isPlaying)
        #expect(info.elapsed == 61)
    }

    @Test("Другой трек — newTrack, elapsedTimeMicros вместо elapsedTimeNowMicros, без обложки")
    func anotherTrack() {
        var parser = NowPlayingParser()
        _ = parser.consume(Self.lines[0], now: Self.now)
        guard case let .newTrack(info)? = parser.consume(Self.lines[2], now: Self.now) else { Issue.record("ожидали newTrack"); return }
        #expect(info.title == "Water")
        #expect(info.elapsed == 0)
        #expect(info.artwork == nil)
    }

    @Test("stream без --now: elapsed отсчитывается от timestampEpochMicros, а не от момента разбора")
    func elapsedAnchoredToTimestamp() {
        var parser = NowPlayingParser()
        guard case let .newTrack(info)? = parser.consume(Self.lines[2], now: Self.now) else { Issue.record("ожидали newTrack"); return }
        #expect(info.duration == 180)
        #expect(info.elapsedAt == Date(timeIntervalSince1970: 1_000_500))
        #expect(info.position(at: Date(timeIntervalSince1970: 1_000_510)) == 10)
    }

    @Test("Пустой payload — cleared, текущий трек сбрасывается")
    func emptyPayloadClears() {
        var parser = NowPlayingParser()
        _ = parser.consume(Self.lines[0], now: Self.now)
        #expect(parser.consume(Self.lines[3], now: Self.now) == .cleared)
        #expect(parser.current == nil)
    }

    @Test("Пустой payload без текущего трека ничего не меняет")
    func emptyPayloadWhenNothingPlays() {
        var parser = NowPlayingParser()
        #expect(parser.consume(Self.lines[3], now: Self.now) == nil)
    }

    @Test("Пустая первая строка перезапущенного адаптера не сбрасывает трек, тот же трек дальше — updated")
    func relaunchEmptyLineKeepsTrack() {
        var parser = NowPlayingParser()
        _ = parser.consume(Self.lines[0], now: Self.now)
        #expect(parser.consume(Self.lines[3], now: Self.now, ignoringClear: true) == nil)
        #expect(parser.current?.title == "Fire")
        guard case .updated? = parser.consume(Self.lines[1], now: Self.now) else { Issue.record("ожидали updated"); return }
    }

    @Test("Переключение треков и браузер: prohibitsSkip из адаптера, без ключа — по списку браузеров")
    func canSkip() {
        func info(_ bundle: String, _ extra: String = "") -> NowPlayingInfo? {
            var parser = NowPlayingParser()
            let line = #"{"type":"data","payload":{"bundleIdentifier":"\#(bundle)","title":"T","playing":true\#(extra)}}"#
            guard case let .newTrack(info) = parser.consume(line) else { return nil }
            return info
        }
        #expect(info("com.apple.Music")?.canSkip == true)
        #expect(info("com.apple.Music")?.isBrowser == false)
        #expect(info("com.google.Chrome")?.canSkip == false)
        #expect(info("com.google.Chrome")?.isBrowser == true)
        #expect(info("com.apple.Music", #","prohibitsSkip":true"#)?.canSkip == false)
        let modes = info("com.apple.Music", #","shuffleMode":3,"repeatMode":2"#)
        #expect(modes?.shuffleMode == 3 && modes?.repeatMode == 2)
    }

    @Test("Мусор и чужие типы строк игнорируются")
    func garbage() {
        var parser = NowPlayingParser()
        _ = parser.consume(Self.lines[0], now: Self.now)
        #expect(parser.consume("not json", now: Self.now) == nil)
        #expect(parser.consume(#"{"type":"error","message":"x"}"#, now: Self.now) == nil)
        #expect(parser.current?.title == "Fire")
    }
}
