import Foundation
import IslandCore
import Testing

@testable import Oasis

@MainActor
struct DemoSequenceTests {
  @Test("--demo-after читается из аргументов запуска")
  func launchDelay() {
    #expect(DemoSequence.launchDelay(arguments: ["app", "--demo-after", "3"]) == 3)
    #expect(DemoSequence.launchDelay(arguments: ["app"]) == nil)
    #expect(DemoSequence.launchDelay(arguments: ["app", "--demo-after"]) == nil)
  }

  @Test("Шаги, с которых стартуют сегменты сверки, стоят в те же секунды, что в capture/targets.json")
  func stepsMatchTargets() throws {
    let repo = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: repo.appendingPathComponent("capture/targets.json"))
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let segments = try #require(json["segments"] as? [[String: Any]])
    let starts = Set(segments.compactMap { $0["start"] as? Double })
    let steps = Set(DemoSequence.steps(store: IslandStore()).map(\.at))
    // сегменты, которые начинает событие, а не таймер машины (сжатие и раскрытие идут сами)
    for start in [1.0, 5.5, 11.0, 13.0, 14.5] {
      #expect(starts.contains(start), "в targets.json нет сегмента с start \(start)")
      #expect(steps.contains(start), "в DemoSequence нет шага на \(start) с")
    }
  }
}

// Тесты на отмену и восстановление конфига живут в DebugScriptTests: там же общий для процесса
// DebugScript.current, и суита сериализована, чтобы прогоны не отменяли друг друга
