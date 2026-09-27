// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AlcoveAnalog",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "IslandCore"),
        .target(name: "IslandSources", dependencies: ["IslandCore"]),
        .target(name: "IslandUI", dependencies: ["IslandCore"]),
        .executableTarget(name: "AlcoveAnalog", dependencies: ["IslandCore", "IslandSources", "IslandUI"]),
        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "IslandSourcesTests", dependencies: ["IslandSources", "IslandCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "IslandUITests", dependencies: ["IslandUI", "IslandCore"]),
        // исполняемый таргет тестируется через @testable import: SwiftPM переименовывает точку входа main
        .testTarget(name: "AlcoveAnalogTests", dependencies: ["AlcoveAnalog", "IslandCore"]),
    ]
)
