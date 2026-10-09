import Combine
import IslandCore
import IslandSources

/// Выбор источника наблюдает клиент, перезапуск разрешает только подтверждённая кнопка
@MainActor
final class YandexMusicConnection: ObservableObject {
  @Published private(set) var state: NowPlayingSourceState = .requiresConnection
  @Published private(set) var commandError: String?
  @Published private(set) var isBusy = false
  private let client: any YandexClient
  private var pendingState: NowPlayingSourceState?

  init(client: any YandexClient = YandexMusicClient.shared) { self.client = client }

  func receive(_ state: NowPlayingSourceState) {
    if case .commandFailed(_, let message) = state {
      commandError = message
      return
    }
    if isBusy {
      pendingState = state
      return
    }
    self.state = state
    commandError = nil
  }

  func connect() async {
    guard !isBusy else { return }
    isBusy = true
    pendingState = nil
    state = .connecting
    commandError = nil
    defer {
      pendingState = nil
      isBusy = false
    }
    do {
      try await client.connect()
      state = pendingState ?? .connecting
    } catch {
      state = Self.failure(error)
    }
  }

  func disconnect() async {
    guard !isBusy else { return }
    isBusy = true
    pendingState = nil
    commandError = nil
    defer {
      pendingState = nil
      isBusy = false
    }
    do {
      try await client.disconnect()
      state = .requiresConnection
    } catch {
      state = Self.failure(error)
    }
  }

  private static func failure(_ error: any Error) -> NowPlayingSourceState {
    switch error as? YandexClientError {
    case .appNotFound: .appNotFound
    case .appClosed: .appClosed
    case .requiresConnection: .requiresConnection
    case .notReady: .notReady
    default: .failed(error.localizedDescription)
    }
  }
}
