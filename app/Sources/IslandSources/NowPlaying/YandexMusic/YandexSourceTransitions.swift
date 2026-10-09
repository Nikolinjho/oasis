import Foundation
import os

/// Общая очередь смены экземпляров: новый bridge ждёт завершения очистки предыдущего.
enum YandexSourceTransitions {
  private static let tail = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

  static func enqueue(_ operation: @escaping @Sendable () async -> Void) {
    tail.withLock { last in
      let previous = last
      last = Task {
        await previous?.value
        await operation()
      }
    }
  }
}
