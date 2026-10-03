import Foundation

/// Layout компактов конкретных активностей поверх контракта ActivityLayout
public enum ActivityLayouts {
  /// Красный календарный: иконка, кольцо и секунды одного цвета (ui-inspection 3.5). Точного цвета нет, оценка по кадру
  public static let calendarRed = RGB(red: 1, green: 0.27, blue: 0.23)
  /// Тёмно-красный трек кольца. Оценка по кадру cal-compact.jpg
  public static let calendarTrack = RGB(red: 0.35, green: 0.08, blue: 0.08)
  /// Самый широкий индикатор компакта календаря: «15m» в момент открытия окна (T−15), дальше минуты и секунды
  /// только убывают, кольцо уже. У Alcove ширина компакта без музыки фиксирована (254, замер 1.7.7), пол
  /// (IslandGeometry.calendarSize) считается по этому индикатору, а не по текущему. С музыкой размер задаёт
  /// компакт музыки, пол не участвует
  public static let calendarWidestIndicator = ActivityLayout.Indicator.text("15m", color: calendarRed)
  /// Самый широкий индикатор напоминания — тоже «15m», но у напоминания свой пол ширины
  /// (IslandGeometry.size(for:notch:reminderIndicatorWidth:)). Самое раннее напоминание — за 15 минут
  public static let reminderWidestIndicator = ActivityLayout.Indicator.text("15m", color: calendarRed)

  /// Компакт календаря (Alcove 1.7.9, 29.09). До начала — минуты вверх («9m»), с музыкой и без (решение
  /// пользователя 30.09), последняя минута — секунды. Кольцо — только ход идущего события.
  /// withMusic: иконка — обложка трека с бейджем часов. С showsLine — строка peek на старте.
  /// style: Use calendar color (иконка, минуты и кольцо) и Use colored calendar indicator (полоска peek)
  public static func calendar(
    event: CalendarEvent, now: Date, showsLine: Bool, withMusic: Bool = false, style: CalendarAppearance = .init()
  ) -> ActivityLayout {
    let tint = style.usesCalendarColor ? event.color : calendarRed
    let track = style.usesCalendarColor ? dimmed(event.color) : calendarTrack
    let untilStart = event.start.timeIntervalSince(now)
    let indicator: ActivityLayout.Indicator
    if untilStart > 60 {
      indicator = .text("\(Int((untilStart / 60).rounded(.up)))m", color: tint)
    } else if untilStart > 0 {
      indicator = .text("\(Int(untilStart.rounded(.up)))s", color: tint)
    } else {
      let length = max(event.end.timeIntervalSince(event.start), 1)
      indicator = .ring(progress: -untilStart / length, color: tint, track: track)
    }
    let line =
      showsLine
      ? ActivityLayout.Line(
        bar: event.color, title: event.title, trailingSymbol: "hourglass",
        trailing: remaining(event.end.timeIntervalSince(now)))
      : nil
    // бейдж на обложке — часы на красном круге (кадр пользователя 29.09); без музыки — прежняя иконка
    return ActivityLayout(
      symbol: withMusic ? "clock" : "calendar.badge.clock", symbolColor: tint,
      indicator: indicator, line: line, showsArtwork: withMusic)
  }

  /// Трек кольца в цвете календаря: тот же цвет, приглушённый как calendarTrack от calendarRed (~0.35)
  static func dimmed(_ color: RGB) -> RGB {
    RGB(red: color.red * 0.35, green: color.green * 0.35, blue: color.blue * 0.35)
  }

  /// Напоминание за N минут: тот же вид, что peek календаря, но вместо кольца — минуты до начала.
  /// У Alcove такого нет (peek Before event starts не снимался): вид — решение плана P1
  public static func reminder(_ reminder: CalendarReminder) -> ActivityLayout {
    ActivityLayout(
      symbol: "calendar.badge.clock", symbolColor: calendarRed,
      indicator: .text("\(reminder.minutes)m", color: calendarRed),
      line: .init(bar: reminder.color, title: reminder.title, trailingSymbol: "clock", trailing: "in \(reminder.minutes) min"))
  }

  /// «59s», «12m», «1h 5m»: как в peek Alcove на старте события
  public static func remaining(_ seconds: TimeInterval) -> String {
    let total = Int(max(seconds, 0).rounded(.up))
    if total < 60 { return "\(total)s" }
    let minutes = total / 60
    if minutes < 60 { return "\(minutes)m" }
    return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
  }

  /// Зелёное кольцо заряда AirPods (ui-inspection 3.6). Точного цвета нет: системный зелёный, оценка
  public static let connectivityGreen = RGB(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
  /// Тёмно-зелёный трек кольца. Замера нет, оценка
  public static let connectivityTrack = RGB(red: 0.08, green: 0.25, blue: 0.1)
  /// Тёплый белый текста острова (IslandPalette.foreground)
  public static let glyphWhite = RGB(red: 1, green: 250 / 255, blue: 244 / 255)

  /// Кольцо низкого заряда наушников. У Alcove не снимали: красный Low Battery (IslandPalette.lowBattery), оценка
  public static let lowBatteryRed = RGB(red: 1, green: 69 / 255, blue: 58 / 255)

  /// Компакт AirPods: белый глиф модели слева, кольцо заряда справа, текста нет (ui-inspection 3.6).
  /// Без заряда — пустое кольцо. Низкий заряд — красное кольцо на тёмно-красном треке календаря
  public static func airpods(_ info: AirPodsInfo) -> ActivityLayout {
    let ring: ActivityLayout.Indicator =
      info.isLowBattery
      ? .ring(progress: info.battery ?? 0, color: lowBatteryRed, track: calendarTrack)
      : .ring(progress: info.battery ?? 0, color: connectivityGreen, track: connectivityTrack)
    return ActivityLayout(symbol: info.symbol, symbolColor: glyphWhite, indicator: ring)
  }
}
