import CoreGraphics
import Testing
@testable import IslandCore

struct GeometryTests {
    /// MacBook Pro 16": экран 1728×1117 pt, вырез по API 185×32 (лог window 28.09).
    /// Раньше фикстура была 186 — ширина по строке 1 pt, где уже начинаются ушки
    static let mbp16 = NotchMetrics(
        screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        auxiliaryTopLeft: CGRect(x: 0, y: 1085, width: 771.5, height: 32),
        auxiliaryTopRight: CGRect(x: 956.5, y: 1085, width: 771.5, height: 32),
        safeAreaTop: 32)!

    @Test("Вырез — промежуток между auxiliary-областями")
    func notchFromAuxiliaryAreas() {
        #expect(Self.mbp16.notchSize == CGSize(width: 185, height: 32))
        #expect(Self.mbp16.notchRect == CGRect(x: 771.5, y: 1085, width: 185, height: 32))
    }

    @Test("Подгонка выреза: сдвиг в pt к размеру по API, вырез остаётся по центру экрана")
    func tuning() {
        let tuned = Self.mbp16.tuned(by: NotchTuning(width: -2, height: 1))
        #expect(tuned.notchSize == CGSize(width: 183, height: 33))
        #expect(tuned.notchRect == CGRect(x: 772.5, y: 1084, width: 183, height: 33))
        #expect(Self.mbp16.tuned(by: NotchTuning()) == Self.mbp16)
        // сдвиг не даёт вырезу схлопнуться в ноль
        #expect(Self.mbp16.tuned(by: NotchTuning(width: -500, height: -500)).notchSize == CGSize(width: 1, height: 1))
    }

    @Test("Без auxiliary-областей выреза нет")
    func noNotch() {
        let metrics = NotchMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            auxiliaryTopLeft: nil, auxiliaryTopRight: nil, safeAreaTop: 0)
        #expect(metrics == nil)
    }

    @Test("Размеры тела острова совпадают с замерами Alcove без ушек")
    func surfaceSizes() {
        let notch = Self.mbp16.notchSize
        func size(_ surface: Surface, media: Bool = true) -> CGSize {
            IslandGeometry.spec(for: surface, hasMedia: media, notch: notch, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0).size
        }
        #expect(size(.idle) == notch)
        #expect(size(.compact) == CGSize(width: 257, height: 32))
        #expect(size(.peek) == CGSize(width: 276, height: 51))
        #expect(size(.hover, media: true) == CGSize(width: 190, height: 73))
        #expect(size(.hover, media: false) == CGSize(width: 203, height: 90))
        #expect(size(.expanded) == CGSize(width: 345, height: 175))
        #expect(size(.hud(.volume, level: 0.5)) == CGSize(width: 367, height: 32))
        #expect(size(.shrink) == CGSize(width: 188, height: 32))
    }

    @Test("Charging: тело 350×32, ушко как у HUD")
    func chargingSize() {
        let spec = IslandGeometry.spec(for: .alert(.charging(level: 0.5)), hasMedia: true, notch: Self.mbp16.notchSize, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        #expect(spec.size == CGSize(width: 350, height: 32))
        #expect(spec.shoulder == IslandGeometry.Shoulder.hud)
    }

    @Test("Календарь: компакт 254×32 и peek 270×73.5 на обычном вырезе, ушко компакта как у музыки")
    func calendarSizes() {
        let notch = Self.mbp16.notchSize
        let compact = IslandGeometry.spec(for: .calendar, hasMedia: false, notch: notch, calendarIndicatorWidth: 22, reminderIndicatorWidth: 0)
        #expect(compact.size == CGSize(width: 254, height: 32))
        #expect(compact.shoulder == IslandGeometry.Shoulder.compact)
        let peek = IslandGeometry.spec(for: .calendarPeek, hasMedia: false, notch: notch, calendarIndicatorWidth: 22, reminderIndicatorWidth: 0)
        #expect(peek.size == CGSize(width: 270, height: 73.5))
    }

    @Test("Календарь на широком вырезе не уже, чем нужно индикатору по обе стороны")
    func calendarWidthFloor() {
        let wide = CGSize(width: 240, height: 32)
        // 240 + 2 × (8 + 22): индикатор шире иконки 18
        let compact = IslandGeometry.spec(for: .calendar, hasMedia: false, notch: wide, calendarIndicatorWidth: 22, reminderIndicatorWidth: 0)
        #expect(compact.size.width == 300)
        let nudge = IslandGeometry.spec(for: .hoverNudge(from: .calendar), hasMedia: false, notch: wide, calendarIndicatorWidth: 22, reminderIndicatorWidth: 0)
        #expect(nudge.size.width == 300 * IslandGeometry.hoverNudgeWidthScale)
    }

    @Test("Календарь при музыке — размеры музыки: компакт 257×32, peek 276×73.5 (Alcove 1.7.9: 258 и 277, 29.09)")
    func calendarWithMusic() {
        func size(_ surface: Surface) -> CGSize {
            IslandGeometry.spec(
                for: surface, hasMedia: true, notch: Self.mbp16.notchSize, calendarIndicatorWidth: 0,
                reminderIndicatorWidth: 0, calendarWithMusic: true).size
        }
        #expect(size(.calendar) == CGSize(width: 257, height: 32))
        #expect(size(.calendarPeek) == CGSize(width: 276, height: 73.5))
    }

    @Test("Радиус нижних углов по видео Alcove: 10.5 в покое, 35 в раскрытом, линейно по высоте")
    func radiusFromVideo() {
        #expect(abs(IslandGeometry.bottomRadius(forHeight: 32) - 10.5) < 1e-9)
        #expect(abs(IslandGeometry.bottomRadius(forHeight: 175) - 35) < 1e-9)
        #expect(abs(IslandGeometry.bottomRadius(forHeight: 103.5) - 22.75) < 1e-9)
    }

    @Test("Радиус нижних углов меньше половины высоты")
    func radiusFitsHeight() {
        let surfaces: [Surface] = [
            .idle, .compact, .peek, .hover, .expanded, .shrink, .hud(.brightness, level: 1),
            .hoverNudge(from: .idle), .hoverNudge(from: .compact), .hoverNudge(from: .peek),
        ]
        for surface in surfaces {
            let spec = IslandGeometry.spec(for: surface, hasMedia: true, notch: Self.mbp16.notchSize, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
            #expect(spec.bottomRadius < spec.size.height / 2, "\(surface)")
        }
    }

    @Test("Окно прижато к верху экрана по центру выреза")
    func windowFrame() {
        #expect(IslandGeometry.windowFrame(for: Self.mbp16) == CGRect(x: 624, y: 861, width: 480, height: 256))
    }

    @Test("Строка громкости: плеер 345×207, углы как у 175 (Alcove 1.7.9, 28.09)")
    func volumeRow() {
        let spec = IslandGeometry.spec(
            for: .expanded, hasMedia: true, notch: Self.mbp16.notchSize, calendarIndicatorWidth: 0,
            reminderIndicatorWidth: 0, volumeRow: true)
        #expect(spec.size == CGSize(width: 345, height: 207))
        #expect(abs(spec.bottomRadius - 35) < 1e-9)
        let shadow = IslandGeometry.Shadow.self
        #expect(IslandGeometry.windowSize.height >= spec.size.height + shadow.y + shadow.reach)
        // тот же плеер, растянутый свайпом вниз до потолка (SwipeTracker.stretchCeiling): окно должно
        // вмещать и это — самое высокое состояние острова (item 3 финального ревью P2)
        let stretched = spec.size.height + SwipeTracker.stretchCeiling
        #expect(IslandGeometry.windowSize.height >= stretched + shadow.y + shadow.reach)
    }

    @Test("Окно вмещает пик перелёта раскрытия из покоя вместе с ушками и тенью")
    func windowFitsOvershoot() throws {
        let notch = Self.mbp16.notchSize
        for transition in [IslandTransition.expand, .hoverExpand] {
            let overshoot = try #require(IslandMotion.spring(for: transition)).overshoot
            let expanded = IslandGeometry.expanded
            let body = expanded.width + overshoot * (expanded.width - notch.width)
            let shoulder = IslandGeometry.Shoulder.expanded
                + overshoot * (IslandGeometry.Shoulder.expanded - IslandGeometry.Shoulder.idle)
            let shadow = IslandGeometry.Shadow.self
            #expect(IslandGeometry.windowSize.width >= body + 2 * shoulder + 2 * shadow.reach, "\(transition)")
            let height = expanded.height + overshoot * (expanded.height - notch.height)
            #expect(IslandGeometry.windowSize.height >= height + shadow.y + shadow.reach)
        }
    }

    @Test("Экранный прямоугольник острова включает ушки своего состояния")
    func islandScreenRect() {
        let window = IslandGeometry.windowFrame(for: Self.mbp16)
        let spec = IslandGeometry.spec(for: .compact, hasMedia: true, notch: Self.mbp16.notchSize, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        let rect = IslandGeometry.islandScreenRect(spec, windowFrame: window)
        #expect(abs(rect.minX - 726.7) < 1e-9 && abs(rect.width - 274.6) < 1e-9)
        #expect(rect.maxY == 1117 && rect.height == 32)
        let expanded = IslandGeometry.spec(for: .expanded, hasMedia: true, notch: Self.mbp16.notchSize, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        #expect(abs(IslandGeometry.islandScreenRect(expanded, windowFrame: window).width - 381.6) < 1e-9)
    }

    @Test("Ушки по состояниям: покой и раскрытый по видео, компакт, peek и HUD по записям, hover — оценка")
    func shoulders() {
        let notch = Self.mbp16.notchSize
        func shoulder(_ surface: Surface, media: Bool = true) -> CGFloat {
            IslandGeometry.spec(for: surface, hasMedia: media, notch: notch, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0).shoulder
        }
        #expect(shoulder(.idle) == 5.15)
        #expect(shoulder(.compact) == 8.8)
        #expect(shoulder(.peek) == 9.8)
        #expect(shoulder(.hud(.volume, level: 0.5)) == 8.7)
        #expect(shoulder(.shrink) == 8.8)
        #expect(shoulder(.expanded) == 18.3)
        #expect(shoulder(.hover, media: true) == 11.3)
        #expect(shoulder(.hover, media: false) == 12.5)
    }

    /// Расстояние от борта до края ушка по строкам пикселей (2x) на центре строки
    static func earProfile(_ surface: Surface, rows: [CGFloat]) -> [CGFloat] {
        let spec = IslandGeometry.spec(for: surface, hasMedia: true, notch: mbp16.notchSize, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        let path = IslandOutline.path(size: spec.size, bottomRadius: spec.bottomRadius, shoulder: spec.shoulder)
        return rows.map { row in
            let y = (row + 0.5) / 2
            var x: CGFloat = 0
            while x < spec.shoulder, !path.contains(CGPoint(x: x, y: y)) { x += 0.01 }
            return spec.shoulder - x
        }
    }

    @Test("Профиль ушка раскрытого и покоя совпадает с видео Alcove в пределах 0.5 pt")
    func earProfileMatchesVideo() {
        // видео hover-открытия 2026-09-26: расстояние от борта, px при 2x, по строкам сверху
        let open: [(row: CGFloat, px: CGFloat)] = [
            (0, 29.4), (2, 20.9), (4, 16.8), (6, 13.4), (8, 10.9), (10, 9.0), (12, 7.3), (14, 5.8), (16, 4.6),
            (18, 3.5), (20, 2.7), (22, 2.0), (24, 1.4), (26, 0.9), (28, 0.7), (30, 0.3), (32, 0), (40, 0),
        ]
        let rest: [(row: CGFloat, px: CGFloat)] = [(0, 6.7), (1, 4.4), (2, 3.0), (3, 2.1), (4, 1.0), (6, 0.3), (7, 0), (12, 0)]
        for (surface, reference) in [(Surface.expanded, open), (.idle, rest)] {
            let measured = Self.earProfile(surface, rows: reference.map(\.row))
            for (row, value) in zip(reference, measured) {
                #expect(abs(value - row.px / 2) <= 0.5, "\(surface) строка \(row.row): \(value) против \(row.px / 2)")
            }
        }
    }

    static func rects(_ surface: Surface, media: Bool = true) -> (body: CGRect, island: CGRect) {
        let window = IslandGeometry.windowFrame(for: mbp16)
        let spec = IslandGeometry.spec(for: surface, hasMedia: media, notch: mbp16.notchSize, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        return (IslandGeometry.bodyScreenRect(spec, windowFrame: window), IslandGeometry.islandScreenRect(spec, windowFrame: window))
    }

    @Test("Тело острова в покое — ровно вырез, без ушек")
    func idleBodyIsNotch() {
        #expect(Self.rects(.idle, media: false).body == Self.mbp16.notchRect)
    }

    @Test("Hover держится над формой, из которой открылся: у края компакта нет мигания")
    func hoverHysteresis() {
        let compact = Self.rects(.compact)
        let hover = Self.rects(.hover)
        // край компакта: внутри тела компакта, но левее узкой hover-формы
        let edge = CGPoint(x: compact.body.minX + 3, y: 1107)
        #expect(!hover.island.contains(edge))

        // вход: курсор над телом компакта
        #expect(IslandGeometry.pointerInside(edge, body: compact.body, island: compact.island, openedFrom: nil))
        // hover открыт: форма сузилась, но курсор над компактом, из которого hover открылся
        #expect(IslandGeometry.pointerInside(edge, body: hover.body, island: hover.island, openedFrom: compact.body))
        // без запомненной формы курсор оказался бы снаружи и hover бы закрылся
        #expect(!IslandGeometry.pointerInside(edge, body: hover.body, island: hover.island, openedFrom: nil))
        // уход за пределы обеих форм закрывает hover
        let away = CGPoint(x: compact.island.minX - 5, y: 1107)
        #expect(!IslandGeometry.pointerInside(away, body: hover.body, island: hover.island, openedFrom: compact.body))
    }

    @Test("Отклик на hover: на 10% шире исходного состояния, высота, радиус и ушки те же",
          arguments: [Surface.idle, .compact, .peek])
    func hoverNudgeShape(from: Surface) {
        let notch = Self.mbp16.notchSize
        let base = IslandGeometry.spec(for: from, hasMedia: true, notch: notch, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        let nudge = IslandGeometry.spec(for: .hoverNudge(from: from), hasMedia: true, notch: notch, calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        #expect(abs(nudge.size.width - base.size.width * 1.1) < 1e-9)
        #expect(nudge.size.height == base.size.height)
        #expect(nudge.bottomRadius == base.bottomRadius)
        #expect(nudge.shoulder == base.shoulder)
    }

    @Test("Курсор над откликом внутри: у расширенного края и над компактом, из которого он открылся")
    func hoverNudgeKeepsPointer() {
        let compact = Self.rects(.compact)
        let nudge = Self.rects(.hoverNudge(from: .compact))
        #expect(nudge.body.contains(compact.body))
        let center = CGPoint(x: compact.body.midX, y: 1107)
        #expect(IslandGeometry.pointerInside(center, body: nudge.body, island: nudge.island, openedFrom: compact.body))
        // за краем компакта, но над расширенной формой
        let widened = CGPoint(x: compact.island.minX - 5, y: 1107)
        #expect(IslandGeometry.pointerInside(widened, body: nudge.body, island: nudge.island, openedFrom: compact.body))
        let away = CGPoint(x: nudge.island.minX - 5, y: 1107)
        #expect(!IslandGeometry.pointerInside(away, body: nudge.body, island: nudge.island, openedFrom: compact.body))
    }

    @Test("Вход в hover только над телом: рядом с вырезом и над ушком не срабатывает")
    func entryOnlyOverBody() {
        let idle = Self.rects(.idle, media: false)
        let beside = CGPoint(x: Self.mbp16.notchRect.minX - 20, y: 1107)
        #expect(!IslandGeometry.pointerInside(beside, body: idle.body, island: idle.island, openedFrom: nil))
        let onEar = CGPoint(x: idle.body.minX - 1, y: 1116.5)
        #expect(idle.island.contains(onEar))
        #expect(!IslandGeometry.pointerInside(onEar, body: idle.body, island: idle.island, openedFrom: nil))
        let below = CGPoint(x: Self.mbp16.notchRect.midX, y: Self.mbp16.notchRect.minY - 2)
        #expect(!IslandGeometry.pointerInside(below, body: idle.body, island: idle.island, openedFrom: nil))
        let over = CGPoint(x: Self.mbp16.notchRect.midX, y: 1100)
        #expect(IslandGeometry.pointerInside(over, body: idle.body, island: idle.island, openedFrom: nil))
    }

    @Test("Курсор, упёртый в верх экрана над вырезом, считается внутри")
    func pointerAtTopEdge() {
        let top = CGPoint(x: Self.mbp16.notchRect.midX, y: Self.mbp16.screenFrame.maxY)
        let idle = Self.rects(.idle, media: false)
        let expanded = Self.rects(.expanded)
        // NSRect.contains не включает maxY: без поправки курсор у края экрана был бы снаружи
        #expect(!idle.body.contains(top))
        #expect(IslandGeometry.pointerInside(top, body: idle.body, island: idle.island, openedFrom: nil))
        #expect(IslandGeometry.pointerInside(top, body: expanded.body, island: expanded.island, openedFrom: idle.body))
        // выше края экрана курсор не бывает, но и там остров не растягивается дальше 1 pt
        let above = CGPoint(x: top.x, y: top.y + 2)
        #expect(!IslandGeometry.pointerInside(above, body: idle.body, island: idle.island, openedFrom: nil))
    }

    static let reminder = IslandAlert.calendarReminder(CalendarReminder(eventID: "call", title: "Созвон", minutes: 15, color: RGB(red: 0.2, green: 0.5, blue: 1)))

    @Test("Напоминание: 270×73.5 на обычном вырезе, ушко — оценка по высоте, как у peek календаря")
    func reminderSize() {
        let spec = IslandGeometry.spec(
            for: .alert(Self.reminder), hasMedia: false, notch: Self.mbp16.notchSize,
            calendarIndicatorWidth: 22, reminderIndicatorWidth: 26)
        #expect(spec.size == CGSize(width: 270, height: 73.5))
        #expect(spec.shoulder == IslandGeometry.Shoulder.estimated(forHeight: 73.5))
    }

    @Test("Напоминание на широком вырезе не уже, чем нужно «15m» по обе стороны, — пол свой, не календаря")
    func reminderWidthFloor() {
        let wide = CGSize(width: 240, height: 32)
        // 240 + 2 × (8 + 26): пол по индикатору напоминания, ширина календаря (22) здесь ни при чём
        let spec = IslandGeometry.spec(
            for: .alert(Self.reminder), hasMedia: false, notch: wide,
            calendarIndicatorWidth: 22, reminderIndicatorWidth: 26)
        #expect(spec.size.width == 308)
        #expect(IslandGeometry.size(for: Self.reminder, notch: wide, reminderIndicatorWidth: 26).width == 308)
    }

    @Test("AirPods: компакт 254×32 как у календаря, ушко как у уведомлений")
    func airpodsSize() {
        let airpods = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 1))
        let spec = IslandGeometry.spec(
            for: .alert(airpods), hasMedia: false, notch: Self.mbp16.notchSize,
            calendarIndicatorWidth: 0, reminderIndicatorWidth: 0)
        #expect(spec.size == CGSize(width: 254, height: 32))
        #expect(spec.shoulder == IslandGeometry.Shoulder.hud)
    }

    @Test("AirPods на широком вырезе: кольцо и глиф не уходят под вырез")
    func airpodsWidthFloor() {
        let airpods = IslandAlert.airpods(AirPodsInfo(name: "AirPods Pro", battery: 1))
        // 240 + 2 × (8 + 18): кольцо 16 уже иконки 18, крыло по иконке
        #expect(IslandGeometry.size(for: airpods, notch: CGSize(width: 240, height: 32), reminderIndicatorWidth: 0).width == 292)
    }

    @Test("Hide label: крыло Low Battery и Low Power по правому блоку (замера нет, оценка)")
    func unlabeledBatteryAlerts() {
        let notch = Self.mbp16.notchSize
        func width(_ alert: IslandAlert, _ style: BatteryAlertStyle) -> CGFloat {
            IslandGeometry.size(for: alert, notch: notch, reminderIndicatorWidth: 0, battery: style).width
        }
        let hidden = BatteryAlertStyle(hidesLabel: true)
        #expect(width(.lowBattery(level: 0.1), hidden) == notch.width + 2 * 80)
        #expect(width(.lowBattery(level: 0.1), BatteryAlertStyle(hidesLabel: true, hidesPercentage: true)) == notch.width + 2 * 46)
        #expect(width(.lowPower(level: 0.4), hidden) == notch.width + 2 * 46)
        #expect(width(.lowBattery(level: 0.1), BatteryAlertStyle()) == notch.width + 2 * IslandGeometry.BatteryAlertWing.lowBattery)
        #expect(width(.charging(level: 0.5), hidden) == IslandGeometry.charging.width)
    }
}
