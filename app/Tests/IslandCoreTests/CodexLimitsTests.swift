import Foundation
import Testing

@testable import IslandCore

struct CodexLimitsTests {
  @Test("Недельное окно Codex не превращается в пятичасовое")
  func weeklyPrimary() throws {
    let data = Data(
      #"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":47,"windowDurationMins":10080,"resetsAt":2000000000},"secondary":null}}"#
        .utf8)
    let limits = try #require(CodexLimits.parse(data, now: Date(timeIntervalSince1970: 100)))
    let window = try #require(limits.buckets.first?.windows.first)
    #expect(window.title == "7 дней")
    #expect(window.remaining == 53)
    #expect(limits.buckets.first?.windows.count == 1)
  }

  @Test("Именованные лимиты не дублируют совместимое окно")
  func multipleBuckets() throws {
    let data = Data(
      #"{"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":20,"windowDurationMins":300},"secondary":{"usedPercent":40,"windowDurationMins":10080}},"other":{"limitName":"Другой лимит","primary":{"usedPercent":50,"windowDurationMins":60}}}}"#
        .utf8)
    let limits = try #require(CodexLimits.parse(data))
    #expect(limits.buckets.count == 2)
    #expect(limits.buckets[0].id == "codex")
    #expect(limits.buckets[0].windows.map(\.title) == ["5 часов", "7 дней"])
    #expect(limits.buckets[1].title == "Другой лимит")
  }

  @Test("Отсутствие лимитов и некорректный процент не означают полный остаток")
  func invalidData() {
    for json in ["{}", #"{"rateLimits":null}"#, #"{"rateLimits":{"primary":{"usedPercent":true}}}"#] {
      #expect(CodexLimits.parse(Data(json.utf8)) == nil)
    }
  }

  @Test("Codex доступен отдельным разделом без сессий")
  func navigation() {
    #expect(ExpandedView(rawValue: "codex")?.backTarget == .modules)
    let layout = DashboardLayout(media: false, calendar: false, claude: false, codex: true, soon: false)
    #expect(layout.moduleViews.map(\.rawValue) == ["codex"])
  }
}
