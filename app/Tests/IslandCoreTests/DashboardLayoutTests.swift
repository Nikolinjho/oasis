import Foundation
import Testing

@testable import IslandCore

struct DashboardLayoutTests {
  @Test("Без Soon обзор теряет его колонку и разделитель")
  func overviewWithoutSoon() {
    let full = DashboardLayout(media: true, calendar: true, claude: true, soon: true)
    let reduced = DashboardLayout(media: true, calendar: true, claude: true, soon: false)
    #expect(full.size(for: .overview) == ExpandedLayout.dashboard)
    #expect(reduced.size(for: .overview).width == 539)
    #expect(full.size(for: .overview).width - reduced.size(for: .overview).width == 229)
  }

  @Test("Каталог исключает отключённые модули и уменьшается на ширину плитки с интервалом")
  func modulesWithoutSoon() {
    let full = DashboardLayout(media: true, calendar: true, claude: true, soon: true)
    let reduced = DashboardLayout(media: true, calendar: true, claude: true, soon: false)
    #expect(!reduced.moduleViews.contains(.soon))
    #expect(full.size(for: .modules).width - reduced.size(for: .modules).width == 104)
  }

  @Test("Все сочетания модулей помещаются с учётом камеры, пустой каталог не содержит плиток")
  func combinations() {
    for flags in 0..<16 {
      let layout = DashboardLayout(
        media: flags & 1 != 0, calendar: flags & 2 != 0, claude: flags & 4 != 0,
        soon: flags & 8 != 0)
      for view in [ExpandedView.overview, .modules] {
        let size = layout.size(for: view)
        #expect(size.width >= 345)
        #expect(size.width <= ExpandedLayout.dashboard.width)
        #expect(size.height == ExpandedLayout.dashboard.height)
      }
      #expect(layout.moduleViews.contains(.duo) == (layout.media && layout.calendar))
      #expect(layout.moduleViews.contains(.claude) == layout.claude)
      if flags == 0 { #expect(layout.moduleViews.isEmpty) }
    }
    let wideNotch = DashboardLayout(media: false, calendar: false, claude: false, soon: false, notchWidth: 220)
    #expect(wideNotch.size(for: .overview).width == 380)
  }
}
