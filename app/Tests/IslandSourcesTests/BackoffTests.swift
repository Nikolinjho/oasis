import Testing
@testable import IslandSources

@Test("Перезапуск адаптера: 1, 2, 4 … 30 с, после успеха снова с 1")
func backoffSequence() {
    var backoff = Backoff()
    let delays = (0..<7).map { _ in backoff.next() }
    #expect(delays == [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(16), .seconds(30), .seconds(30)])
    backoff.reset()
    #expect(backoff.next() == .seconds(1))
}
