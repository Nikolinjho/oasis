import Foundation
import Testing

@testable import IslandSources

struct YandexSnapshotTests {
  @Test("Снапшот сохраняет id, секунды позиции и явные возможности")
  func snapshot() throws {
    let data = Data(
      """
      {"version":1,"state":"ready","sampledAt":1780000000,"trackID":"90111503","title":"God Breathed","artist":"Ye","album":"Donda","isPlaying":false,"duration":333.46,"position":0,"artworkURL":"https://avatars.yandex.net/a/400x400","isFavorite":null,"shuffleMode":1,"repeatMode":1,"capabilities":{"canPlayPause":true,"canNext":true,"canPrevious":false,"canSeek":true,"canFavorite":false,"shuffleModes":[1,3],"repeatModes":[1,3,2]}}
      """.utf8)
    let value = try JSONDecoder().decode(YandexSnapshot.self, from: data)
    let info = try #require(value.info)
    #expect(info.sourceTrackID == "90111503")
    #expect(info.elapsed == 0)
    #expect(info.elapsedAt == Date(timeIntervalSince1970: 1_780_000_000))
    #expect(info.capabilities.canPrevious == false)
    #expect(info.capabilities.requiresConfirmation)
    #expect(info.isFavorite == nil)
  }
  @Test("Неполный снапшот не создаёт неполный трек")
  func missing() throws {
    let value = try JSONDecoder().decode(YandexSnapshot.self, from: Data("{\"version\":1,\"state\":\"notReady\",\"sampledAt\":0}".utf8))
    #expect(value.info == nil)
  }
  @Test("Живые фикстуры альбома и Волны сохраняют разные циклы режимов", arguments: ["album", "vibe"])
  func liveFixtures(_ name: String) throws {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/YandexMusic"))
    let snapshot = try JSONDecoder().decode(YandexSnapshot.self, from: Data(contentsOf: url))
    let info = try #require(snapshot.info)
    #expect(info.capabilities.repeatModes == (name == "vibe" ? [1, 2] : [1, 3, 2]))
    #expect(info.capabilities.shuffleModes == (name == "vibe" ? [] : [1, 3]))
    #expect(info.duration == (name == "vibe" ? 188.40671201814058 : 333.46))
  }

}
