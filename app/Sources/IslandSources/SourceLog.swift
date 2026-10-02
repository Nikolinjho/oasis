import os

enum SourceLog {
  static let subsystem = "dev.nikoko.alcove-analog"

  static func logger(_ category: String) -> Logger {
    Logger(subsystem: subsystem, category: category)
  }
}
