import Foundation
import Testing

@testable import IslandSources

/// Живая проверка против настоящего адаптера. Нужна играющая музыка: ADAPTER_TESTS=1 swift test --filter AdapterLiveTests
@Test("Живой адаптер отдаёт текущий трек", .enabled(if: ProcessInfo.processInfo.environment["ADAPTER_TESTS"] == "1"))
func liveAdapter() async throws {
  let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let vendor = app.appendingPathComponent("Vendor/mediaremote-adapter").path
  let paths = try #require(AdapterPaths.locate(bundle: .main, environment: ["OASIS_ADAPTER_DIR": vendor]))
  let source = AdapterNowPlayingSource(paths: paths)
  source.start()
  defer { source.stop() }

  let first = await withTaskGroup(of: NowPlayingChange?.self) { group in
    group.addTask {
      for await change in source.changes { return change }
      return nil
    }
    group.addTask {
      try? await Task.sleep(for: .seconds(5))
      return nil
    }
    let result = await group.next() ?? nil
    group.cancelAll()
    return result
  }
  guard case .newTrack(let info)? = first else {
    Issue.record("за 5 с трека нет: включи музыку, пришло \(String(describing: first))")
    return
  }
  #expect(!info.title.isEmpty)
}
