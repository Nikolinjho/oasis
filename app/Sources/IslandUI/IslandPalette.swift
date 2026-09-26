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
}
