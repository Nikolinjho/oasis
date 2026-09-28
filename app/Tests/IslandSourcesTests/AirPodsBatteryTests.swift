import Foundation
import Testing
@testable import IslandSources

struct AirPodsBatteryTests {
    static func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "bluetooth", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test("Заряд подключённых: меньший из наушников, иначе Main, без данных — nil")
    func battery() throws {
        let data = try Self.fixture()
        #expect(AirPodsBattery.parse(json: data, name: "AirPods Pro") == 0.82)
        #expect(AirPodsBattery.parse(json: data, name: "AirPods Max") == 0.64)
        #expect(AirPodsBattery.parse(json: data, name: "MX Master 3") == nil)
        #expect(AirPodsBattery.parse(json: data, name: "AirPods 4") == nil)
    }

    @Test("Наушники по имени: AirPods всех моделей и Beats")
    func headphones() {
        for name in ["AirPods Pro", "AirPods Max", "Nikita’s AirPods 4 (ANC)", "Beats Studio Pro"] {
            #expect(AirPodsBattery.isHeadphones(name: name), "\(name)")
        }
        #expect(!AirPodsBattery.isHeadphones(name: "MX Master 3"))
    }
}
