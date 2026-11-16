import Foundation
import IslandCore
import Testing

@testable import Oasis

@MainActor
struct IslandStoreDashboardTests {
  @Test("Отключение Soon сразу сужает форму обзора и её область клика")
  func disablingSoonResizesIsland() {
    let store = IslandStore()
    store.applySoon(SoonPanel(reminders: [], now: Date()))
    store.send(.clicked)
    store.send(.expandedViewRequested(.overview))
    #expect(store.model.surface == .expanded)
    #expect(store.contentSpec.size.width == 768)

    store.applySoon(nil)
    #expect(store.model.expandedView == .overview)
    #expect(store.contentSpec.size.width == 539)
    #expect(store.spec.size.width == 539)
    let body = IslandGeometry.bodyScreenRect(store.spec, windowFrame: CGRect(x: 0, y: 0, width: 960, height: 360))
    #expect(body.width == 539)
  }

  @Test("Раздел Claude открывает лимиты и возвращает в каталог")
  func limitsNavigation() {
    let store = IslandStore()
    let now = Date()
    let limits = ClaudeLimits(
      fiveHour: ClaudeWindow(usedPercent: 20, resetsAt: now.addingTimeInterval(3600)),
      sevenDay: nil, capturedAt: now)
    store.applyClaude(ClaudePanel(limits: limits, day: nil, now: now, horizon: .midnight, calendar: .current))
    store.send(.clicked)
    store.selectExpandedView(.claude)
    #expect(store.model.surface == .expanded)
    #expect(store.model.expandedView == .claude)
    #expect(store.navigateBack())
    #expect(store.model.expandedView == .modules)
    store.applyClaude(nil)
    store.selectExpandedView(.claude)
    #expect(store.model.expandedView == .modules)
  }
}
