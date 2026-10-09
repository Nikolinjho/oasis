import Foundation
import Testing

@testable import IslandSources

struct YandexEndpointTests {
  @Test("Разрешена только страница Яндекс Музыки и её локальный websocket")
  func target() throws {
    let good = Data(
      "[{\"type\":\"page\",\"url\":\"music-application://desktop/playlists?id=4\",\"webSocketDebuggerUrl\":\"ws://127.0.0.1:12345/devtools/page/A\"}]"
        .utf8)
    #expect(try YandexEndpoint.websocket(from: good, port: 12345).port == 12345)
    for (page, socket) in [
      ("https://music.yandex.ru", "ws://127.0.0.1:12345/devtools/page/A"),
      ("music-application://desktop", "ws://remote.test:12345/devtools/page/A"),
      ("music-application://desktop", "ws://127.0.0.1:12346/devtools/page/A"),
      ("music-application://auth", "ws://127.0.0.1:12345/devtools/page/A"),
    ] {
      let data = Data("[{\"type\":\"page\",\"url\":\"\(page)\",\"webSocketDebuggerUrl\":\"\(socket)\"}]".utf8)
      #expect(throws: (any Error).self) { try YandexEndpoint.websocket(from: data, port: 12345) }
    }
  }
  @Test("Чужой PID или публичный listener не допускается")
  func ownership() {
    #expect(YandexEndpoint.isOwned([.init(pid: 12, address: "127.0.0.1:12345")], pid: 12, port: 12345))
    #expect(!YandexEndpoint.isOwned([.init(pid: 13, address: "127.0.0.1:12345")], pid: 12, port: 12345))
    #expect(!YandexEndpoint.isOwned([.init(pid: 12, address: "*:12345")], pid: 12, port: 12345))
    #expect(
      !YandexEndpoint.isOwned([.init(pid: 12, address: "127.0.0.1:12345"), .init(pid: 12, address: "*:12345")], pid: 12, port: 12345))
  }
}
