import Foundation
import IslandCore
import IslandSources

/// Ресурсы адаптера нужны только System, скрипт Яндекса передаётся источнику явно
struct NowPlayingSourceFactory {
  var adapterPaths: () -> AdapterPaths? = { AdapterPaths.locate() }
  var bridgeScript: () -> String? = {
    Bundle.main.url(forResource: "player-bridge", withExtension: "js", subdirectory: "YandexMusic")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
  }
  var client: any YandexClient = YandexMusicClient.shared

  func make(_ choice: MediaSourceChoice) -> (any NowPlayingSource)? {
    switch choice {
    case .system: return adapterPaths().map { AdapterNowPlayingSource(paths: $0) }
    case .yandexMusic:
      guard let script = bridgeScript() else { return nil }
      return YandexMusicSource(script: script, client: client)
    }
  }
}
