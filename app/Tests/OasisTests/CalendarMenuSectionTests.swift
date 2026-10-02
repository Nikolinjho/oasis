import AppKit
import IslandCore
import Testing

@testable import Oasis

@MainActor
struct CalendarMenuSectionTests {
  static func event(notes: String?, startsIn seconds: TimeInterval = 480, now: Date = Date()) -> CalendarEvent {
    CalendarEvent(
      id: "call@1", title: "Созвон", start: now.addingTimeInterval(seconds), end: now.addingTimeInterval(seconds + 1800),
      isAllDay: false, color: RGB(red: 0.2, green: 0.5, blue: 1), notes: notes)
  }

  static func fire(_ item: NSMenuItem) {
    _ = (item.target as? NSObject)?.perform(item.action, with: item)
  }

  @Test("Три пункта с иконками, как у Alcove; без ссылки — без Join")
  func items() {
    var joined: [URL] = []
    var opened: [String] = []
    var dismissed: [String] = []
    let actions = CalendarMenuSection.Actions(
      join: { joined.append($0) }, open: { opened.append($0.event.id) }, dismiss: { dismissed.append($0) })
    let meet = CalendarMenuModel(event: Self.event(notes: nil), meeting: URL(string: "https://meet.google.com/abc-defg-hij"))
    let items = CalendarMenuSection.items(for: meet, actions: actions)
    #expect(items.map(\.title) == ["Join Google Meet", "Open in Calendar", "Dismiss Event"])
    #expect(items.allSatisfy { $0.image != nil })
    // 18×18, как *AppIcon18x18.png у Alcove; символы — не шаблоны: шаблонный символ в меню не рисовался
    #expect(items.allSatisfy { $0.image?.size == NSSize(width: 18, height: 18) })
    #expect(items[2].image?.isTemplate == false)

    Self.fire(items[0])
    Self.fire(items[1])
    Self.fire(items[2])
    #expect(joined.map(\.host) == ["meet.google.com"])
    #expect(opened == ["call@1"])
    #expect(dismissed == ["call@1"])

    let plain = CalendarMenuModel(event: Self.event(notes: nil), meeting: nil)
    #expect(CalendarMenuSection.items(for: plain, actions: actions).map(\.title) == ["Open in Calendar", "Dismiss Event"])
    #expect(CalendarMenuSection.items(for: nil, actions: actions).isEmpty)
  }

  /// Непрозрачные пиксели картинки, нарисованной в 18×18: пустая картинка ненулевого размера — не иконка
  static func inkedPixels(_ image: NSImage) -> Int {
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 18, pixelsHigh: 18, bitsPerSample: 8, samplesPerPixel: 4,
      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
    NSGraphicsContext.restoreGraphicsState()
    var count = 0
    for x in 0..<18 { for y in 0..<18 where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { count += 1 } }
    return count
  }

  @Test("Иконки пунктов рисуются, а не пустые квадраты")
  func iconsHaveInk() {
    let actions = CalendarMenuSection.Actions(join: { _ in }, open: { _ in }, dismiss: { _ in })
    let meet = CalendarMenuModel(event: Self.event(notes: nil), meeting: URL(string: "https://telemost.yandex.ru/j/1"))
    for item in CalendarMenuSection.items(for: meet, actions: actions) {
      #expect(Self.inkedPixels(try! #require(item.image)) > 20, "\(item.title)")
    }
  }

  @Test("Символ рисуется и вне главного потока: drawing handler не требует MainActor")
  func symbolOffMain() async {
    let inked = await Task.detached { () -> Int in
      let image = CalendarMenuSection.symbol("xmark.circle.fill")
      let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 18, pixelsHigh: 18, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
      image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
      NSGraphicsContext.restoreGraphicsState()
      var count = 0
      for x in 0..<18 { for y in 0..<18 where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { count += 1 } }
      return count
    }.value
    #expect(inked > 20)
  }

  @Test("Иконка сервиса без приложения и без картинки в бандле — video.fill 18×18")
  func fallbackServiceIcon() {
    // тестовый бинарь не лежит в .app: Icons/google-meet.png нет, у Telemost своего приложения нет
    let video = CalendarMenuSection.symbol("video.fill")
    for service in [MeetingService?.none, .telemost, .googleMeet] {
      let icon = CalendarMenuSection.serviceIcon(service)
      #expect(icon.size == video.size)
      #expect(Self.inkedPixels(icon) > 20)
    }
  }

  @Test("Dismiss Event убирает компакт календаря и пункты меню")
  func dismissInClock() {
    let now = Date()
    let store = IslandStore(config: .alcove)
    let clock = CalendarClock(store: store, start: now)
    // начало через 30 с: окно календаря уже открыто (liveLead 15 минут)
    clock.update(
      agenda: DayAgenda(today: [Self.event(notes: "https://meet.google.com/abc-defg-hij", startsIn: 30, now: now)], tomorrow: []), now: now)
    #expect(store.model.calendarLive)
    #expect(clock.menuModel(now: now)?.event.id == "call@1")

    clock.dismiss("call@1", now: now)
    #expect(!store.model.calendarLive)
    #expect(clock.menuModel(now: now) == nil)
  }

  @Test("Меню пересобирается при каждом открытии: пункты события первыми, за ними разделитель")
  func statusMenuRebuild() {
    var current: [NSMenuItem] = []
    let controller = StatusItemController(
      debugItem: NSMenuItem(title: "Debug", action: nil, keyEquivalent: ""),
      isTrusted: { true }, openSettings: {}, calendarItems: { current })
    let menu = controller.menu
    let base = menu.items.map(\.title)

    controller.menuWillOpen(menu)
    #expect(menu.items.map(\.title) == base)

    current = [
      NSMenuItem(title: "Open in Calendar", action: nil, keyEquivalent: ""),
      NSMenuItem(title: "Dismiss Event", action: nil, keyEquivalent: ""),
    ]
    controller.menuWillOpen(menu)
    #expect(Array(menu.items.prefix(3).map(\.title)) == ["Open in Calendar", "Dismiss Event", ""])
    #expect(menu.items[2].isSeparatorItem)
    #expect(Array(menu.items.dropFirst(3).map(\.title)) == base)

    // второе открытие не дублирует пункты
    controller.menuWillOpen(menu)
    #expect(menu.items.count == base.count + 3)

    current = []
    controller.menuWillOpen(menu)
    #expect(menu.items.map(\.title) == base)
  }
}
