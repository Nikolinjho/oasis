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
        #expect(AirPodsBattery.device(json: data, name: "AirPods Pro")?.battery == 0.82)
        #expect(AirPodsBattery.device(json: data, name: "AirPods Max")?.battery == 0.64)
        #expect(AirPodsBattery.device(json: data, name: "MX Master 3")?.battery == nil)
        // не подключены — устройства нет вовсе
        #expect(AirPodsBattery.device(json: data, name: "AirPods 4") == nil)
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

    @Test("Процент: пробелы не мешают, значение зажато в 0…1")
    func percent() {
        #expect(AirPodsBattery.percent("85 %") == 0.85)
        #expect(AirPodsBattery.percent(" 82%") == 0.82)
        #expect(AirPodsBattery.percent("120%") == 1)
        #expect(AirPodsBattery.percent("-5%") == 0)
        #expect(AirPodsBattery.percent("n/a") == nil)
        #expect(AirPodsBattery.percent(nil) == nil)
    }

    @Test("Пачка подключений: одно чтение на всех, без заряда — один повтор, не наушники отбрасываются")
    func resolveBatch() throws {
        typealias Connection = AirPodsBattery.Connection
        let data = try Self.fixture()
        let first = AirPodsBattery.resolve([
            Connection(name: "AirPods Pro", address: nil): false,
            Connection(name: "Kitchen", address: nil): false,
            Connection(name: "MX Master 3", address: nil): false,
            Connection(name: "Fresh AirPods", address: "aa-bb-cc-dd-ee-99"): false,
        ], json: data)
        #expect(Set(first.show.map(\.name)) == ["AirPods Pro", "Kitchen"])
        // «Fresh AirPods» ещё не попали в system_profiler: заряда нет, ждём ещё одно окно
        #expect(first.retry == [Connection(name: "Fresh AirPods", address: "aa-bb-cc-dd-ee-99")])
        let second = AirPodsBattery.resolve([Connection(name: "Fresh AirPods", address: "aa-bb-cc-dd-ee-99"): true], json: data)
        #expect(second.show == [AirPodsInfo(name: "Fresh AirPods", battery: nil)])
        #expect(second.retry.isEmpty)
        // system_profiler не ответил: то же правило, что без заряда
        let failed = AirPodsBattery.resolve([Connection(name: "AirPods Pro", address: nil): false], json: nil)
        #expect(failed.show.isEmpty)
        #expect(failed.retry == [Connection(name: "AirPods Pro", address: nil)])
    }

    @Test("Переименованные в system_profiler наушники находятся по адресу, имя в сведениях — от IOBluetooth")
    func lookupByAddress() throws {
        let data = try Self.fixture()
        // IOBluetooth: «AirPods 4 (ANC)», адрес строчными через дефис; system_profiler: «Den», адрес через двоеточие
        let den = try #require(AirPodsBattery.device(json: data, name: "AirPods 4 (ANC)", address: "aa-bb-cc-dd-ee-09"))
        #expect(den.battery == 0.75)
        #expect(!den.isAppleHeadphones)
        let result = AirPodsBattery.resolve(
            [AirPodsBattery.Connection(name: "AirPods 4 (ANC)", address: "aa-bb-cc-dd-ee-09"): false], json: data)
        #expect(result.show == [AirPodsInfo(name: "AirPods 4 (ANC)", battery: 0.75)])
        #expect(result.retry.isEmpty)
        // адрес не нашёлся — поиск по имени, как раньше
        #expect(AirPodsBattery.device(json: data, name: "Kitchen", address: "aa-bb-cc-dd-ee-99")?.battery == 0.6)
        #expect(AirPodsBattery.device(json: data, name: "Kitchen", address: nil)?.battery == 0.6)
        #expect(AirPodsBattery.device(json: data, name: "Nobody", address: "aa-bb-cc-dd-ee-99") == nil)
    }

    @Test("Дубли одной записи в system_profiler сливаются: недостающие поля берутся из любой")
    func mergeDuplicates() throws {
        let data = try Self.fixture()
        // первая запись «Office» — только левый наушник, вторая — правый, vendorID, minorType и productID
        for device in [
            AirPodsBattery.device(json: data, name: "Office", address: nil),
            AirPodsBattery.device(json: data, name: "Something Else", address: "AA-BB-CC-DD-EE-0A"),
        ] {
            let office = try #require(device)
            #expect(office.battery == 0.3)
            #expect(office.isAppleHeadphones)
            #expect(office.model == .pro)
        }
    }

    @Test("Вывод процесса целиком")
    func output() async {
        let data = await AirPodsBattery.output(of: URL(fileURLWithPath: "/bin/echo"), arguments: ["hi"], timeout: 5)
        #expect(data.map { String(decoding: $0, as: UTF8.self) } == "hi\n")
    }

    @Test("Завис процесс: по таймауту он завершается, результат nil")
    func outputTimeout() async {
        let start = ContinuousClock.now
        let data = await AirPodsBattery.output(of: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], timeout: 0.3)
        #expect(data == nil)
        #expect(ContinuousClock.now - start < .seconds(3))
    }

    @Test("Процесс глушит SIGTERM: результат nil по таймауту, не дожидаясь конца процесса")
    func outputIgnoresTerm() async {
        let start = ContinuousClock.now
        let data = await AirPodsBattery.output(
            of: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "trap '' TERM; sleep 10"], timeout: 0.3)
        #expect(data == nil)
        #expect(ContinuousClock.now - start < .seconds(3))
    }

    @Test("Не запустился процесс — nil, без зависания")
    func outputMissingExecutable() async {
        let data = await AirPodsBattery.output(of: URL(fileURLWithPath: "/nonexistent/tool"), arguments: [], timeout: 5)
        #expect(data == nil)
    }
}
