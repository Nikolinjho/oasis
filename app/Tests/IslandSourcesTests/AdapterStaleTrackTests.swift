import IslandCore
import Testing
@testable import IslandSources

struct AdapterStaleTrackTests {
    @Test("Проверка старого трека — только после перезапуска, на пустой первой строке, если трек был")
    func startsStaleCheck() {
        #expect(AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 2, change: nil, hasTrack: true))
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 1, change: nil, hasTrack: true))
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: false, generation: 2, change: nil, hasTrack: true))
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 2, change: nil, hasTrack: false))
        let track = NowPlayingInfo(title: "T", isPlaying: true)
        #expect(!AdapterNowPlayingSource.startsStaleCheck(isFirstLine: true, generation: 2, change: .newTrack(track), hasTrack: true))
    }

    @Test("Пустая (или непарсящаяся) первая строка перезапуска вооружает проверку, строка с треком её снимает")
    func lineArmsAndDisarms() {
        var check = AdapterNowPlayingSource.StaleTrackCheck()
        let armed = check.line(isFirst: true, generation: 2, change: nil, hadTrack: true)
        #expect(armed)
        #expect(check.awaiting)

        let track = NowPlayingInfo(title: "T", isPlaying: true)
        let disarmed = check.line(isFirst: false, generation: 2, change: .newTrack(track), hadTrack: false)
        #expect(!disarmed)
        #expect(!check.awaiting)
    }

    @Test("Первый запуск (generation 1) проверку не вооружает")
    func firstLaunchNeverArms() {
        var check = AdapterNowPlayingSource.StaleTrackCheck()
        let armed = check.line(isFirst: true, generation: 1, change: nil, hadTrack: true)
        #expect(!armed)
        #expect(!check.awaiting)
    }

    @Test("Таймаут снимает трек только если проверка ещё активна, запуск тот же, адаптер не остановлен и трек есть")
    func timeoutDropsOnlyWhenStillWaiting() {
        var armed = AdapterNowPlayingSource.StaleTrackCheck()
        _ = armed.line(isFirst: true, generation: 2, change: nil, hadTrack: true)

        var notArmed = AdapterNowPlayingSource.StaleTrackCheck()
        let notArmedResult = notArmed.timeout(generation: 2, currentGeneration: 2, stopped: false, hasTrack: true)
        #expect(!notArmedResult)

        var newerGeneration = armed
        let newerGenerationResult = newerGeneration.timeout(generation: 2, currentGeneration: 3, stopped: false, hasTrack: true)
        #expect(!newerGenerationResult)

        var stoppedAdapter = armed
        let stoppedResult = stoppedAdapter.timeout(generation: 2, currentGeneration: 2, stopped: true, hasTrack: true)
        #expect(!stoppedResult)

        var noTrackLeft = armed
        let noTrackResult = noTrackLeft.timeout(generation: 2, currentGeneration: 2, stopped: false, hasTrack: false)
        #expect(!noTrackResult)

        var dropped = armed
        let droppedResult = dropped.timeout(generation: 2, currentGeneration: 2, stopped: false, hasTrack: true)
        #expect(droppedResult)
        #expect(!dropped.awaiting)
    }
}
