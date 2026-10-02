import os

enum SourceLog {
  static let subsystem = "dev.nikoko.oasis"

  static func logger(_ category: String) -> Logger {
    Logger(subsystem: subsystem, category: category)
  }
}
