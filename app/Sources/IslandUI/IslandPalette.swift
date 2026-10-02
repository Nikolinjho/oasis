import SwiftUI

/// Цвета острова. Фон чисто чёрный: пробы нативного Alcove дают #000000 (осмотр 26.09),
/// тёплый #0C0A09 был из веб-демо. Текст тёплый белый orange-25 из веб-демо, в нативном не проверяли
public enum IslandPalette {
  public static let background = Color.black
  public static let foreground = Color(red: 1, green: 250 / 255, blue: 244 / 255)
  public static let secondary = foreground.opacity(0.6)
  /// Квадрат вместо обложки у браузерных источников
  public static let placeholder = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
  /// Подложка кнопки плеера под курсором
  public static let pressed = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
  /// Подложка в момент нажатия, чуть ярче. Замера нет, оценка
  public static let pressedActive = Color(red: 40 / 255, green: 40 / 255, blue: 42 / 255)
  /// Duo: подложка Play под курсором ~36×36, осмотр 26.09 (ui-inspection 3.3)
  public static let duoHover = Color(red: 25 / 255, green: 25 / 255, blue: 26 / 255)
  /// Разделитель колонок Duo, 1 pt. Цвет не мерили, оценка по кадру island-expanded-duo.png, ≈ #1A1A1A
  public static let divider = Color(white: 26 / 255)
  /// День недели над датой. Не мерили: акцент Alcove #E96260, по кадру похож
  public static let dateAccent = Color(red: 233 / 255, green: 98 / 255, blue: 96 / 255)
  /// Вторая строка пустого дня темнее первой. Оценка по кадру
  public static let tertiary = foreground.opacity(0.35)
  /// Батарейка Charging: зелёная (rec2/states-sheet.png). Точного цвета нет: системный зелёный, оценка
  public static let charging = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
  /// Low Battery: красная батарейка. Цвета не снимали: системный красный, оценка
  public static let lowBattery = Color(red: 1, green: 69 / 255, blue: 58 / 255)
  /// Low Power Mode: жёлтая батарейка, как у macOS. Оценка
  public static let lowPower = Color(red: 1, green: 214 / 255, blue: 10 / 255)
  /// Подложка подгонки выреза (Task 17t): красная плашка Alcove 1.7.9 (29.09, осмотр). Содержимое на ней чёрное
  public static let tuning = Color(red: 233 / 255, green: 103 / 255, blue: 115 / 255)
}
