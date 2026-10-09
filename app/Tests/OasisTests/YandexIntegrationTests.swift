import Foundation
import IslandCore
import IslandSources
import Testing

@testable import Oasis

actor ConnectionClient: YandexClient {
  private(set) var connects = 0
  private(set) var disconnects = 0
  func endpoint() async throws -> URL { throw YandexClientError.requiresConnection }
  func connect() { connects += 1 }
  func disconnect() { disconnects += 1 }
}

final class TypedYandexSource: YandexSourceControlling, @unchecked Sendable {
  let changes: AsyncStream<NowPlayingChange>
  let statuses: AsyncStream<NowPlayingSourceState>
  let stateContinuation: AsyncStream<NowPlayingSourceState>.Continuation
  private(set) var commands: [String] = []
  init() {
    changes = AsyncStream { _ in }
    (statuses, stateContinuation) = AsyncStream.makeStream()
  }
  func start() {}
  func stop() {}
  func send(_ command: MediaCommand) {}
  func setShuffle(_ mode: Int) {}
  func setRepeat(_ mode: Int) {}
  func seek(to position: TimeInterval) { commands.append("unscoped") }
  func seek(to position: TimeInterval, expectedTrackID: String) { commands.append("seek:\(expectedTrackID):\(position)") }
  func setFavorite(to favorite: Bool, expectedTrackID: String) { commands.append("favorite:\(expectedTrackID):\(favorite)") }
}

@MainActor
struct YandexIntegrationTests {
  @Test("Выбор Яндекса не разрешает перезапуск, подключение и отключение вызываются отдельно")
  func explicitConnection() async {
    let client = ConnectionClient()
    let connection = YandexMusicConnection(client: client)
    let source = TypedYandexSource()
    let switcher = NowPlayingSourceSwitcher(make: { _ in source }, onChange: { _ in }, onState: connection.receive)
    switcher.apply(.yandexMusic)
    source.stateContinuation.yield(.requiresConnection)
    for _ in 0..<100 { await Task.yield() }
    #expect(await client.connects == 0)
    #expect(await client.disconnects == 0)
    await connection.connect()
    #expect(await client.connects == 1)
    #expect(connection.state == .connecting)
    connection.receive(.connected)
    connection.receive(.commandFailed(.seek(0), "Rejected"))
    #expect(connection.state == .connected && connection.commandError == "Rejected")
    await connection.disconnect()
    #expect(await client.disconnects == 1)
    #expect(connection.state == .requiresConnection)
    switcher.stop()
  }

  @Test("Запоздавший статус прежней сессии не меняет настройки нового источника")
  func lateStatus() async {
    let old = TypedYandexSource()
    let new = TypedYandexSource()
    var states: [NowPlayingSourceState] = []
    let switcher = NowPlayingSourceSwitcher(make: { $0 == .yandexMusic ? old : new }, onChange: { _ in }, onState: { states.append($0) })
    switcher.apply(.yandexMusic)
    old.stateContinuation.yield(.connected)
    for _ in 0..<1000 where states.isEmpty { await Task.yield() }
    #expect(states == [.connected])
    switcher.apply(.system)
    old.stateContinuation.yield(.failed("Old"))
    new.stateContinuation.yield(.notReady)
    for _ in 0..<1000 where states.count < 2 { await Task.yield() }
    #expect(states == [.connected, .notReady])
    switcher.stop()
    #expect(switcher.source == nil)
  }

  @Test("Фабрика Яндекса не требует ресурсов системного адаптера")
  func factoryResources() {
    var adapterReads = 0
    let factory = NowPlayingSourceFactory(
      adapterPaths: {
        adapterReads += 1
        return nil
      }, bridgeScript: { "bridge" }, client: ConnectionClient())
    #expect(factory.make(.yandexMusic) is YandexMusicSource)
    #expect(adapterReads == 0)
    #expect(factory.make(.system) == nil)
    #expect(adapterReads == 1)
  }

  @Test("Исполнитель Яндекса использует команды с ожидаемым треком и отвергает сменившийся трек")
  func trackScopedPerformer() {
    let source = TypedYandexSource()
    var info = NowPlayingInfo(bundleID: YandexMusicClient.bundleID, title: "A", isPlaying: true, sourceTrackID: "one")
    var current: (any NowPlayingSource)? = source
    let performer = PlayerActions(source: { current }, nowPlaying: { info }, volume: { nil }, onRowVolume: { _ in })
    performer.seek(to: 0, expectedTrackID: "one")
    performer.setFavorite(to: true, expectedTrackID: "one")
    info.sourceTrackID = "two"
    performer.seek(to: 5, expectedTrackID: "one")
    performer.setFavorite(to: false, expectedTrackID: "one")
    current = FakeNowPlayingSource()
    performer.seek(to: 8, expectedTrackID: "two")
    #expect(source.commands == ["seek:one:0.0", "favorite:one:true"])
  }

  @Test("Ошибка режима снимает только его оптимистичное ожидание")
  func failedMode() {
    let store = IslandStore()
    let info = NowPlayingInfo(
      bundleID: YandexMusicClient.bundleID, title: "A", isPlaying: true,
      shuffleMode: 1, repeatMode: 1,
      capabilities: PlayerCapabilities(
        canPlayPause: true, canNext: true, canPrevious: true, canSeek: true,
        canFavorite: true, shuffleModes: [1, 3], repeatModes: [1, 2], requiresConfirmation: true))
    store.apply(.newTrack(info))
    store.playerActionSent(.toggleShuffle)
    store.playerActionSent(.cycleRepeat)
    #expect(store.nowPlaying?.shuffleMode == 3 && store.nowPlaying?.repeatMode == 2)
    store.playerActionFailed(.toggleShuffle)
    #expect(store.nowPlaying?.shuffleMode == 1 && store.nowPlaying?.repeatMode == 2)
    store.playerActionFailed(.cycleRepeat)
    #expect(store.nowPlaying?.repeatMode == 1)
  }
}

actor SuspendedConnectionClient: YandexClient {
  private var connecting: CheckedContinuation<Void, Never>?
  private(set) var started = false
  private(set) var disconnectStarted = false
  private var disconnecting: CheckedContinuation<Void, Never>?
  func endpoint() async throws -> URL { throw YandexClientError.requiresConnection }
  func connect() async {
    started = true
    await withCheckedContinuation { connecting = $0 }
  }
  func finishConnect() {
    connecting?.resume()
    connecting = nil
  }
  func disconnect() async {
    disconnectStarted = true
    await withCheckedContinuation { disconnecting = $0 }
  }
  func finishDisconnect() {
    disconnecting?.resume()
    disconnecting = nil
  }
}

@MainActor
struct YandexConnectionReadinessTests {
  @Test("Статус готовности, пришедший во время подключения, сохраняется после завершения")
  func readinessWhileConnecting() async {
    for status in [NowPlayingSourceState.notReady, .incompatibleVersion, .connected] {
      let client = SuspendedConnectionClient()
      let connection = YandexMusicConnection(client: client)
      let operation = Task { await connection.connect() }
      while !(await client.started) { await Task.yield() }
      connection.receive(status)
      await client.finishConnect()
      await operation.value
      #expect(connection.state == status)
      #expect(!connection.isBusy)
    }
  }

  @Test("Готовность транспорта сама по себе не подтверждает готовность плеера")
  func waitsForSourceReadiness() async {
    let connection = YandexMusicConnection(client: ConnectionClient())
    await connection.connect()
    #expect(connection.state == .connecting)
    connection.receive(.connected)
    #expect(connection.state == .connected)
  }
  @Test("Успешное отключение не восстанавливает запоздавший подключённый статус")
  func ignoresStaleStatusWhileDisconnecting() async {
    let client = SuspendedConnectionClient()
    let connection = YandexMusicConnection(client: client)
    connection.receive(.connected)
    let operation = Task { await connection.disconnect() }
    while !(await client.disconnectStarted) { await Task.yield() }
    connection.receive(.connected)
    await client.finishDisconnect()
    await operation.value
    #expect(connection.state == .requiresConnection)
  }

}
