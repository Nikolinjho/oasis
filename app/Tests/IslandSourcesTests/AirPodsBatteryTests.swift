import Foundation
import Testing
@testable import IslandSources
import IslandCore

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

    @Test("Переименованные наушники Apple распознаются по vendorID 0x004C и minorType Headphones")
    func renamedHeadphones() throws {
        let data = try Self.fixture()
        let kitchen = try #require(AirPodsBattery.device(json: data, name: "Kitchen"))
        #expect(kitchen.isAppleHeadphones)
        #expect(kitchen.battery == 0.6)
        #expect(AirPodsBattery.isHeadphones(name: "Kitchen", device: kitchen))
        // чужие наушники и не-наушники Apple — нет
        #expect(!AirPodsBattery.isHeadphones(name: "WH-1000XM5", device: AirPodsBattery.device(json: data, name: "WH-1000XM5")))
        #expect(!AirPodsBattery.isHeadphones(name: "Magic Keyboard", device: AirPodsBattery.device(json: data, name: "Magic Keyboard")))
        // имя по-прежнему достаточно, даже если system_profiler ничего не отдал
        #expect(AirPodsBattery.isHeadphones(name: "AirPods 4", device: nil))
        #expect(!AirPodsBattery.isHeadphones(name: "Kitchen", device: nil))
    }

    @Test("Модель по productID: известные Pro и Max, остальное — nil и глиф по имени")
    func modelFromProductID() throws {
        let data = try Self.fixture()
        #expect(AirPodsBattery.device(json: data, name: "Studio")?.model == .pro)
        #expect(AirPodsBattery.device(json: data, name: "Kitchen")?.model == nil)
        #expect(AirPodsBattery.model(productID: "0x200A") == .max)
        #expect(AirPodsBattery.model(productID: "0x2024") == .pro)
        #expect(AirPodsBattery.model(productID: nil) == nil)
    }

    @Test("Сведения для уведомления: имя, заряд и модель подключённого устройства")
    func info() throws {
        let data = try Self.fixture()
        let studio = AirPodsBattery.device(json: data, name: "Studio")
        #expect(AirPodsBattery.info(name: "Studio", device: studio) == AirPodsInfo(name: "Studio", battery: 0.4, model: .pro))
        #expect(AirPodsBattery.info(name: "WH-1000XM5", device: AirPodsBattery.device(json: data, name: "WH-1000XM5")) == nil)
        #expect(AirPodsBattery.info(name: "AirPods Max", device: nil) == AirPodsInfo(name: "AirPods Max", battery: nil))
    }
}
