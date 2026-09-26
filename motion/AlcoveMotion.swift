// Константы геометрии и пружин острова, снятые с веб-демо tryalcove.com (см. motion.md)
// Физика Motion и SwiftUI interpolatingSpring совпадает — числа перенесены как есть
import SwiftUI

enum IslandGeometry {
    static let idle = CGSize(width: 112, height: 40)
    static let wide = CGSize(width: 186, height: 40)
    static let peek = CGSize(width: 186, height: 72)

    static let idleRadius: CGFloat = 12
    static let hoverRadius: CGFloat = 13
    /// В peek нижние углы круглее верхних
    static let peekTopRadius: CGFloat = 13
    static let peekBottomRadius: CGFloat = 19

    /// Сглаживание squircle-углов на сайте (у .continuous от Apple около 0.6)
    static let cornerSmoothing: CGFloat = 0.65

    static let hoverScale: CGFloat = 1.075
    static let pressScale: CGFloat = 0.94
    static let hoverShadow = (color: Color(red: 12 / 255, green: 10 / 255, blue: 9 / 255).opacity(0.25), radius: 16.0, y: 2.0)

    /// stone-950 и orange-25 с сайта: тёплые чёрный и белый
    static let background = Color(red: 12 / 255, green: 10 / 255, blue: 9 / 255)
    static let foreground = Color(red: 1, green: 250 / 255, blue: 244 / 255)
}

enum IslandSpring {
    private static func spring(_ stiffness: Double, _ damping: Double) -> Animation {
        .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping)
    }

    static let hoverIn = spring(250, 14)
    static let hoverOut = spring(200, 20)
    static let press = spring(160, 18)

    static let expand = spring(150, 20)
    static let collapseAfterNotification = spring(150, 16)
    static let collapseAfterActivity = spring(175, 17.5)

    static let peekOpen = spring(250, 21)
    static let peekContent = spring(250, 21).delay(0.05)
    static let peekClose = spring(250, 25)

    static let digits = spring(150, 14)
}

/// Измерено по записи нативного приложения 26.09 (capture/analysis) — приоритетнее веб-чисел
enum IslandNativeSpring {
    /// Раскрытие 186×32 → 365×175, перелёт до 382×187.5
    static let open = Animation.interpolatingSpring(mass: 1, stiffness: 175, damping: 16)
    /// Схлопывание без отскока, совпадает с .smooth(duration: 0.4)
    static let close = Animation.smooth(duration: 0.4)
    static let hudIn = Animation.smooth(duration: 0.44)
    static let hudOut = Animation.smooth(duration: 0.45)
    /// Смена активности: сначала сжатие почти до выреза, раскрытие стартует сразу после
    static let handoffShrink = Animation.smooth(duration: 0.33)
    static let handoffGrow = Animation.spring(duration: 0.45, bounce: 0.1)
    static let compactIn = Animation.interpolatingSpring(mass: 1, stiffness: 235, damping: 31)
    static let compactOut = Animation.interpolatingSpring(mass: 1, stiffness: 185, damping: 27.5)
}

enum IslandNativeGeometry {
    /// MacBook Pro 16": покой совпадает с вырезом
    static let idleMBP16 = CGSize(width: 186, height: 32)
    static let expanded = CGSize(width: 365, height: 175)
    static let hoverIntermediate = CGSize(width: 203, height: 90)
    /// HUD растёт только в ширину, высота остаётся как у menu bar
    static let hud = CGSize(width: 374, height: 32)
    static let musicCompact = CGSize(width: 261, height: 32)
    static let musicPeek = CGSize(width: 283, height: 51)
    static let musicExpanded = CGSize(width: 370, height: 175)
    static let charging = CGSize(width: 357, height: 32)
    /// Ширина, до которой сжимается остров при смене активности
    static let handoffWidth: CGFloat = 195
}

enum IslandTiming {
    /// Сколько остров держит ширину после разблокировки, пока играет анимация замка
    static let unlockHold: Duration = .milliseconds(475)
    static let quickPeek: Duration = .milliseconds(2000)
    /// Скорость бегущей строки в peek, px/с
    static let marqueeSpeed: CGFloat = 30

    /// Вход и выход бокового контента: проявление из размытия со сжатием по X
    static let slotIn: Duration = .milliseconds(300)
    static let slotOut: Duration = .milliseconds(250)
    static let slotInBlur: CGFloat = 10
    static let slotOutBlur: CGFloat = 4
    static let slotOutScaleX: CGFloat = 0.25

    /// Периоды полосок эквалайзера, высота пульса 3 → 12 px
    static let equalizerPeriods: [Double] = [0.95, 1.46, 0.82, 1.24]
}
