import SwiftUI

/// Пункты сайдбара в порядке Alcove (ui-inspection 1.1). Готова только General, остальные —
/// заглушки запланированных страниц: затенены и подписаны Soon (решение 27.09). License личной сборке не нужна.
/// Modules — свои модули Oasis, у Alcove их нет; Soon — название приложения, а не бейдж (решение 03.10)
enum SettingsPage: String, CaseIterable, Identifiable {
  case general, battery, connectivity, focus, display, sound, nowPlaying, calendar, fileTray, lockScreen
  case claudeCode, pomodoro, soon
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: "General"
    case .battery: "Battery"
    case .connectivity: "Connectivity"
    case .focus: "Focus"
    case .display: "Display"
    case .sound: "Sound"
    case .nowPlaying: "Now Playing"
    case .calendar: "Calendar"
    case .fileTray: "File Tray"
    case .lockScreen: "Lock Screen"
    case .claudeCode: "Claude Code"
    case .pomodoro: "Pomodoro"
    case .soon: "Soon"
    case .about: "About"
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape.fill"
    case .battery: "bolt.fill"
    case .connectivity: "headphones"
    case .focus: "moon.fill"
    case .display: "sun.max.fill"
    case .sound: "speaker.wave.2.fill"
    case .nowPlaying: "play.fill"
    case .calendar: "calendar"
    case .fileTray: "tray.fill"
    case .lockScreen: "lock.fill"
    case .claudeCode: "sparkle"
    case .pomodoro: "timer"
    case .soon: "checklist"
    case .about: "info"
    }
  }

  /// Цвета иконок по скринам settings-*.png. Точных значений нет: системные цвета macOS, оценка
  var tint: Color {
    switch self {
    case .general, .fileTray, .about: .gray
    case .battery: .orange
    case .connectivity: .green
    case .focus: .indigo
    case .display: .purple
    case .sound: .pink
    case .nowPlaying, .calendar: .red
    // 0.15 сливался с тёмной темой окна: чуть светлее, чтобы иконка не пропадала
    case .lockScreen: Color(white: 0.3)
    // Оранжевый Claude ≈ #D97757: у Alcove таких страниц нет, цвета модулей — оценка
    case .claudeCode: Color(red: 0.85, green: 0.47, blue: 0.34)
    case .pomodoro: .red
    case .soon: .teal
    }
  }

  var group: String? {
    switch self {
    case .general: nil
    case .battery, .connectivity, .focus, .display, .sound: "Notifications"
    case .nowPlaying, .calendar, .fileTray, .lockScreen: "Live Activities"
    case .claudeCode, .pomodoro, .soon: "Modules"
    case .about: "Oasis"
    }
  }

  /// Страницы, готовые в P2. Остальные — затенены и подписаны Soon
  var isAvailable: Bool { Self.available.contains(self) }

  private static let available: Set<SettingsPage> = [
    .general, .battery, .connectivity, .display, .sound, .nowPlaying, .calendar, .claudeCode,
  ]
}
