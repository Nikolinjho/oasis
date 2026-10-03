import CoreGraphics

public struct IslandShapeSpec: Equatable, Sendable {
  public var size: CGSize
  public var bottomRadius: CGFloat
  /// Ширина ушка с каждой стороны. Зависит от состояния и анимируется вместе с размером
  public var shoulder: CGFloat

  public init(size: CGSize, bottomRadius: CGFloat, shoulder: CGFloat = 0) {
    self.size = size
    self.bottomRadius = bottomRadius
    self.shoulder = shoulder
  }
}

/// Размеры тела острова без ушек (MacBook Pro 16"). Ширины в capture/analysis/README.md сняты трекером
/// по строке 1 pt ниже края экрана и включают часть ушек: компакт 263.5 (в README 261), peek 284 (283),
/// раскрытый 370, HUD 374, сжатие 195. Здесь ширина тела по кадрам, где борт отделён от ушка
public enum IslandGeometry {
  /// rec2/player-sheet.png, 4-й ряд: тело 514 px
  public static let compact = CGSize(width: 257, height: 32)
  /// rec2/player-sheet.png, 5-й ряд: тело 552 px
  public static let peek = CGSize(width: 276, height: 51)
  /// Тело не мерили: ширина из README (строка 1 pt, с ушками), оценка
  public static let hoverWithMedia = CGSize(width: 190, height: 73)
  /// Тело не мерили: ширина из README (строка 1 pt, с ушками), оценка
  public static let hoverEmpty = CGSize(width: 203, height: 90)
  /// Отклик на hover шире исходной формы в столько раз. Обзорное видео Alcove, 30 fps: за 4 кадра
  /// до раскрытия ширина компакта +8…10%, высота почти та же. Оценка, в масштабе видео без точного замера
  public static let hoverNudgeWidthScale: CGFloat = 1.1
  /// Видео hover-открытия Alcove 2026-09-26: 345.1×175.0 (пик 359.3×187.7); rec2 и кадр пользователя — те же 345
  public static let expanded = CGSize(width: 345, height: 175)
  /// Строка громкости под кнопками плеера: 345×175 → 345×207 (Alcove 1.7.9, осмотр 28.09)
  public static let volumeRowHeight: CGFloat = 32
  /// states/t69.4.png (запись №1): тело 732.5 px, в строке 1 pt ушки добавляют по 3.6 pt с каждой стороны
  public static let hud = CGSize(width: 367, height: 32)
  /// Ширина, до которой остров сжимается при смене активности. Трекер дал 195 по строке 1 pt;
  /// минус те же 7 pt ушек, что у компакта и HUD той же высоты. Выведено, а не измерено напрямую
  public static let shrinkWidth: CGFloat = 188
  /// rec2/states-sheet.png: Charging 357 по строке 1 pt. Тело не мерили: минус 7 pt ушек, как у HUD той же высоты.
  /// Абсолютная ширина, не от выреза: реальный замер, в отличие от lowBattery/lowPower ниже
  public static let charging = CGSize(width: 350, height: 32)
  /// Компакт календаря: тело ~254 по 2x-кадрам ревью Task 3 (cal-snap-230346.png, cal-countdown.jpg, ±2),
  /// «~250» в ui-inspection 3.5 — округление. Ширина у Alcove фиксирована, это пол: см. calendarSize
  public static let calendarCompact = CGSize(width: 254, height: 32)
  /// Peek календаря на старте: по строке y=3 280, тело ~270, высота 73.5 после пика 75.5 (ui-inspection 3.5)
  public static let calendarPeek = CGSize(width: 270, height: 73.5)
  /// Компакт AirPods: той же ширины, что календарный (ui-inspection 3.6), и по строке y=3 оба 259
  /// до и после сжатия между ними — значит, тело то же, что у calendarCompact. Это пол: см. airpodsSize
  public static let airpodsCompact = calendarCompact

  /// Подложка подгонки выреза (Task 17t): высота width-подсказки. Alcove 1.7.9, 29.09, MBP 16",
  /// API-вырез 185, Notch width −1 → плашка 184×69
  public static let tuningWidthHeight: CGFloat = 69
  /// Высота height-подсказки при h = 0 (осмотр 29.09). При иных h — замера нет, оценка «32 + h»
  /// (см. size(for:notch:calendarIndicatorWidth:reminderIndicatorWidth:) case .tuning)
  public static let tuningHeightBase: CGFloat = 32

  /// Ширина компакта AirPods: замер — пол, но не уже, чем нужно кольцу по обе стороны выреза.
  /// Тот же подход, что calendarSize: на широком вырезе глиф и кольцо не уходят под него
  public static func airpodsSize(notch: CGSize) -> CGSize {
    calendarSize(airpodsCompact, notch: notch, indicatorWidth: ActivityLayout.ringWidth)
  }

  /// Ширина компакта и peek календаря: замер — пол, но не уже, чем нужно индикатору по обе стороны выреза
  /// (ActivityLayout.width). Жёсткая ширина без пола уводит длинный индикатор под широкий вырез.
  /// Пол сам растёт вместе с вырезом (задача 1), как и остальные ширины вокруг него
  public static func calendarSize(_ base: CGSize, notch: CGSize, indicatorWidth: CGFloat) -> CGSize {
    let floor = notchRelativeWidth(base.width, notch: notch.width)
    let needed = ActivityLayout.width(notchWidth: notch.width, indicatorWidth: indicatorWidth)
    return CGSize(width: max(floor, needed), height: base.height)
  }

  /// Вырез, на котором сняты все ширины выше (compact, peek, hoverWithMedia, hud, charging,
  /// calendarCompact, calendarPeek): Notch width −2 на API-вырезе 185 pt, то есть тело выреза 183
  /// (ui-inspection 3.1, задача 1). Настройка Notch width двигает эти ширины на свою величину
  /// пт-в-пт (Alcove 1.7.9, 29.09: компакт 257@−2…261@+2, HUD 367@−2…371@+2, раскрытый не меняется)
  public static let referenceNotchWidth: CGFloat = 183

  /// Растягивает ширину, снятую на referenceNotchWidth, на текущий вырез notch — 1:1, как в Alcove
  /// (задача 1). Для поверхностей, что рисуются вокруг выреза (компакт, peek, hover с музыкой, HUD,
  /// charging, компакт/peek календаря); раскрытый и строка громкости от выреза не зависят
  public static func notchRelativeWidth(_ measured: CGFloat, notch: CGFloat) -> CGFloat {
    measured + (notch - referenceNotchWidth)
  }

  /// Крыло Low Battery/Low Power по одной стороне от выреза: подпись + 14 padding (BatteryAlertView.padding)
  /// + 4 запаса, замера нет — оценка. Итоговая ширина = notch.width + 2×wing, крылья симметричны.
  /// В отличие от Charging (абсолютный замер) считается от реального выреза: на экране с укрупнённым текстом
  /// вырез шире 186, и подпись на фиксированной ширине заехала бы под него (ui review, задача 1)
  public enum BatteryAlertWing {
    /// «Low Battery» при 13pt semibold — 75.5 pt, ceil 76 + 14 + 4
    public static let lowBattery: CGFloat = 94
    /// «Low Power Mode» при 13pt semibold — 106.5 pt, ceil 107 + 14 + 4
    public static let lowPower: CGFloat = 125

    /// Hide label: крыло по правому блоку. «10%» при 13pt semibold ~27 pt + зазор 6 + батарейка с носиком 27.5
    /// + padding 14 + 4 запаса ≈ 79 → 80. Без процента: 27.5 + 14 + 4 → 46. Замера нет, оценка
    public static let unlabeledWithPercent: CGFloat = 80
    public static let unlabeled: CGFloat = 46

    public static func lowBatteryWing(_ style: BatteryAlertStyle) -> CGFloat {
      guard style.hidesLabel else { return lowBattery }
      return style.hidesPercentage ? unlabeled : unlabeledWithPercent
    }

    public static func lowPowerWing(_ style: BatteryAlertStyle) -> CGFloat {
      style.hidesLabel ? unlabeled : lowPower
    }
  }

  /// Low Battery и Low Power вживую не снимались: ширина под реальный вырез — см. BatteryAlertWing.
  /// Charging остаётся абсолютным (измеренным), от notch не зависит.
  /// reminderIndicatorWidth — ширина самого широкого индикатора напоминания («15m», меряет IslandUI):
  /// пол ширины напоминания, как calendarIndicatorWidth у компакта календаря. Нужна только .calendarReminder
  public static func size(
    for alert: IslandAlert, notch: CGSize, reminderIndicatorWidth: CGFloat, battery: BatteryAlertStyle = BatteryAlertStyle()
  ) -> CGSize {
    switch alert {
    // как компакт/HUD: тело растёт вместе с вырезом (задача 1). lowBattery/lowPower ниже уже
    // считаются от notch.width напрямую — при них это не нужно
    case .charging: CGSize(width: notchRelativeWidth(charging.width, notch: notch.width), height: charging.height)
    case .lowBattery: CGSize(width: notch.width + 2 * BatteryAlertWing.lowBatteryWing(battery), height: charging.height)
    case .lowPower: CGSize(width: notch.width + 2 * BatteryAlertWing.lowPowerWing(battery), height: charging.height)
    // напоминание не снималось: размер peek календаря (ui-inspection 3.5), тот же вид строки
    case .calendarReminder: calendarSize(calendarPeek, notch: notch, indicatorWidth: reminderIndicatorWidth)
    case .airpods: airpodsSize(notch: notch)
    }
  }

  /// Ушки (вогнутые плечи) по бокам: форма перетекает в menu bar. Ширина геометрическая,
  /// от кончика кривой у края экрана до борта острова; видимая у края меньше (≈0.8), кончик тоньше пикселя.
  /// Форма одна на все состояния (IslandOutline.EarProfile), масштабируется шириной.
  /// В анимации ушко идёт той же пружиной, что размер, то есть линейно по высоте, как в видео.
  /// В видео при раскрытии ушко отстаёт от высоты примерно на 40 мс: пока не повторяем
  public enum Shoulder {
    /// Видео hover-открытия Alcove 2026-09-26, покой (26 кадров): видимая 3.4 pt
    public static let idle: CGFloat = 5.15
    /// rec2/player-sheet.png, 4-й ряд: видимая 6.3 pt, форма из видео легла с СКО 0.13 px
    public static let compact: CGFloat = 8.8
    /// rec2/player-sheet.png, 5-й ряд: видимая 7.1 pt, СКО 0.21 px
    public static let peek: CGFloat = 9.8
    /// states/t69.4.png (запись №1): видимая 6.3 pt, СКО 0.12 px
    public static let hud: CGFloat = 8.7
    /// Замера нет: как у компакта той же высоты 32
    public static let shrink: CGFloat = 8.8
    /// Видео hover-открытия Alcove 2026-09-26, раскрытый (41 кадр, левое и правое в пределах 0.3 px):
    /// видимая 14.7 pt. Кадр ref-ears.png (видимая 25.8 pt) — другое состояние или масштаб, не цель
    public static let expanded: CGFloat = 18.3

    /// Hover не мерили: оценка линейно по высоте между peek (51 → 9.8) и раскрытым (175 → 18.3)
    public static func estimated(forHeight height: CGFloat) -> CGFloat {
      let (h0, s0) = (peekHeight, peek)
      let (h1, s1) = (IslandGeometry.expanded.height, expanded)
      return ((s0 + (height - h0) * (s1 - s0) / (h1 - h0)) * 10).rounded() / 10
    }

    private static let peekHeight = IslandGeometry.peek.height
  }

  /// Мягкая тень вокруг раскрытого острова. Замер видео hover-открытия Alcove 2026-09-26: отношение яркости
  /// обоев в раскрытом (кадры 95–130) к покою (10–35) по бокам и под телом. У борта затемнение 0.30,
  /// под телом 0.33, по бокам сходит на нет к ~30 pt. Тень растёт вместе с раскрытием (кадры 43–50),
  /// в покое её не видно относительно покоя же: есть ли тень у компакта, из видео не понять, считаем что нет
  public enum Shadow {
    /// Непрозрачность чёрного: затемнение у борта 0.30 — половина тени при нулевом сдвиге
    public static let opacity: CGFloat = 0.6
    /// Радиус SwiftUI .shadow: профиль по бокам совпал с профилем SwiftUI при радиусе ≈ 15
    public static let radius: CGFloat = 15
    /// Сдвиг вниз: под телом тень плотнее и длиннее, чем по бокам
    public static let y: CGFloat = 5
    /// Докуда тень SwiftUI заметна от края формы: калибровка рендером, при радиусе 20 затемнение
    /// падает до нуля к 46–48 pt, то есть ≈ 2.4 радиуса
    public static let reach: CGFloat = radius * 2.4
  }

  /// Окно как у Alcove 1.7.9 (осмотр 03.10): 624 × 320. Под ним Progressive blur, который сходит на нет
  /// за 80 pt от формы: раскрытый 381.6 с ушками + 2 × 80 = 541.6 в ширину, 175 + 80 = 255 в высоту.
  /// Прежние 480 × 256 вмещали только пик перелёта с тенью (398.6 × 188.1 + 36 pt тени) и плеер
  /// со строкой громкости, растянутый свайпом (207 + 7 + 41 тени = 255)
  public static let windowSize = CGSize(width: 624, height: 320)

  /// calendarIndicatorWidth — ширина самого широкого индикатора компакта календаря (меряет IslandUI),
  /// нужна только .calendar и .calendarPeek. reminderIndicatorWidth — то же для напоминания
  /// (.alert(.calendarReminder)), см. size(for:notch:reminderIndicatorWidth:). calendarWithMusic — пока
  /// играет музыка, компакт и peek календаря занимают её размеры (Alcove 1.7.9, 29.09)
  public static func spec(  // swiftlint:disable:this cyclomatic_complexity function_body_length - таблица поверхность → форма
    for surface: Surface, hasMedia: Bool, notch: CGSize, calendarIndicatorWidth: CGFloat,
    reminderIndicatorWidth: CGFloat, battery: BatteryAlertStyle = BatteryAlertStyle(),
    calendarWithMusic: Bool = false, volumeRow: Bool = false
  ) -> IslandShapeSpec {
    if case .hoverNudge(let from) = surface {
      // отклик — исходная форма, только шире: радиус и ушки как у неё (оценка)
      var base = spec(
        for: from, hasMedia: hasMedia, notch: notch, calendarIndicatorWidth: calendarIndicatorWidth,
        reminderIndicatorWidth: reminderIndicatorWidth, battery: battery,
        calendarWithMusic: calendarWithMusic, volumeRow: volumeRow)
      base.size.width *= hoverNudgeWidthScale
      return base
    }
    var size: CGSize =
      switch surface {
      case .idle: notch
      // компакт, peek, hover с музыкой и HUD растут вместе с вырезом (задача 1): эталоны сняты
      // на referenceNotchWidth, дальше 1:1 к текущему notch.width
      case .compact: CGSize(width: notchRelativeWidth(compact.width, notch: notch.width), height: compact.height)
      case .peek: CGSize(width: notchRelativeWidth(peek.width, notch: notch.width), height: peek.height)
      case .hover:
        hasMedia
          ? CGSize(width: notchRelativeWidth(hoverWithMedia.width, notch: notch.width), height: hoverWithMedia.height)
          : hoverEmpty
      case .expanded: expanded
      case .shrink: CGSize(width: shrinkWidth, height: notch.height)
      case .hud: CGSize(width: notchRelativeWidth(hud.width, notch: notch.width), height: hud.height)
      case .alert(let alert): size(for: alert, notch: notch, reminderIndicatorWidth: reminderIndicatorWidth, battery: battery)
      // при музыке компакт и peek календаря — размеры музыки (Alcove 1.7.9: 258 и 277, 29.09; теперь
      // тоже notch-relative, потому что сами компакт/peek notch-relative, задача 1)
      case .calendar:
        calendarWithMusic
          ? CGSize(width: notchRelativeWidth(compact.width, notch: notch.width), height: compact.height)
          : calendarSize(calendarCompact, notch: notch, indicatorWidth: calendarIndicatorWidth)
      case .calendarPeek:
        calendarWithMusic
          ? CGSize(width: notchRelativeWidth(peek.width, notch: notch.width), height: calendarPeek.height)
          : calendarSize(calendarPeek, notch: notch, indicatorWidth: calendarIndicatorWidth)
      // Подложка подгонки выреза (Task 17t, Alcove 1.7.9, 29.09): width-подсказка — подогнанный вырез
      // (notch уже пришёл тюнингованным, задача 1) высотой tuningWidthHeight; height-подсказка — ширина
      // компакта той же формулой, что .compact, высота tuningHeightBase + сырое значение ползунка h
      case .tuning(let hint):
        switch hint {
        case .width: CGSize(width: notch.width, height: tuningWidthHeight)
        case .height(let h): CGSize(width: notchRelativeWidth(compact.width, notch: notch.width), height: tuningHeightBase + CGFloat(h))
        }
      // разобран выше, сюда не доходит
      case .hoverNudge: notch
      }
    if surface == .expanded, volumeRow { size.height += volumeRowHeight }
    let shoulder: CGFloat =
      switch surface {
      case .idle: Shoulder.idle
      case .compact: Shoulder.compact
      case .peek: Shoulder.peek
      case .hover: Shoulder.estimated(forHeight: size.height)
      case .expanded: Shoulder.expanded
      case .shrink: Shoulder.shrink
      case .hud: Shoulder.hud
      // замера нет: у строки menu bar — как у HUD, у высоких (напоминание) — оценка по высоте
      case .alert: size.height > 32 ? Shoulder.estimated(forHeight: size.height) : Shoulder.hud
      // замера нет: компакт как у музыки той же высоты, peek — оценка по высоте
      case .calendar: Shoulder.compact
      case .calendarPeek: Shoulder.estimated(forHeight: calendarPeek.height)
      // замера нет: «как у компакта» (задание Task 17t)
      case .tuning: Shoulder.compact
      case .hoverNudge: Shoulder.idle  // разобран выше
      }
    // со строкой громкости углы на кадре те же, что у 175: радиус по высоте без строки (замера нет, оценка)
    let radiusHeight = surface == .expanded && volumeRow ? expanded.height : size.height
    return IslandShapeSpec(size: size, bottomRadius: bottomRadius(forHeight: radiusHeight), shoulder: shoulder)
  }

  /// Радиус нижних углов (squircle-порт с сайта). Замер видео hover-открытия Alcove 2026-09-26,
  /// подгонка контура по коду сайта: 10.5 pt в покое (высота 32), 35 pt в раскрытом (175), на пике 36.
  /// Между ними линейно по высоте. Меньше половины высоты при любой высоте от 32
  public static func bottomRadius(forHeight height: CGFloat) -> CGFloat {
    let (h0, r0): (CGFloat, CGFloat) = (32, 10.5)
    let (h1, r1): (CGFloat, CGFloat) = (175, 35)
    return r0 + (height - h0) * (r1 - r0) / (h1 - h0)
  }

  /// Рамка окна: верх у края экрана, по центру выреза
  public static func windowFrame(for metrics: NotchMetrics) -> CGRect {
    CGRect(
      x: metrics.screenFrame.midX - windowSize.width / 2,
      y: metrics.screenFrame.maxY - windowSize.height,
      width: windowSize.width,
      height: windowSize.height)
  }

  /// Контур острова вместе с ушками в координатах экрана
  public static func islandScreenRect(_ spec: IslandShapeSpec, windowFrame: CGRect) -> CGRect {
    let width = spec.size.width + 2 * spec.shoulder
    return CGRect(
      x: windowFrame.midX - width / 2,
      y: windowFrame.maxY - spec.size.height,
      width: width,
      height: spec.size.height)
  }

  /// Тело острова без ушек в координатах экрана: в покое это ровно вырез
  public static func bodyScreenRect(_ spec: IslandShapeSpec, windowFrame: CGRect) -> CGRect {
    CGRect(
      x: windowFrame.midX - spec.size.width / 2,
      y: windowFrame.maxY - spec.size.height,
      width: spec.size.width,
      height: spec.size.height)
  }

  /// Курсор над островом с гистерезисом. Вход только над видимым телом (без ушек и зон вокруг):
  /// по живой проверке запас вокруг выреза открывал hover, не доходя до острова.
  /// Пока hover открыт (openedFrom не nil), он держится над объединением текущей формы с ушками и тела,
  /// из которого открылся: hover уже компакта, и без этого у краёв компакта hover мигал бы.
  /// expandedSafeZone — только у раскрытого: держит его и в зоне вокруг тела, но не открывает
  public static func pointerInside(
    _ point: CGPoint, body: CGRect, island: CGRect, openedFrom: CGRect?, expandedSafeZone: SafeZone? = nil
  ) -> Bool {
    guard let openedFrom else { return reachingScreenTop(body).contains(point) }
    guard let expandedSafeZone else { return reachingScreenTop(island.union(openedFrom)).contains(point) }
    // зона Alcove считается от тела (замер 03.10). Ушки — только верхняя полоса высотой с ушко: прямоугольник
    // формы с ушками по всей высоте держал бы курсор сбоку дальше зоны
    let ear = (island.width - body.width) / 2
    let ears = CGRect(x: island.minX, y: island.maxY - ear, width: island.width, height: ear)
    // по отдельности: union прямоугольников снова растянул бы ушки на всю высоту
    return [expandedSafeZone.expanding(body), ears, openedFrom].contains { reachingScreenTop($0).contains(point) }
  }

  /// Прямоугольник, растянутый вверх на 1 pt. NSRect.contains не включает maxY, а курсор,
  /// упёртый в верх экрана, стоит ровно на maxY экрана: без растяжки он был бы снаружи острова
  public static func reachingScreenTop(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + 1)
  }
}
