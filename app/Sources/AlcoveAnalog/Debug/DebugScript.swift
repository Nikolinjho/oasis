import Foundation

/// Цепочка отладочных шагов по времени от старта: сценарии Debug и demo-прогон для записи
@MainActor
enum DebugScript {
    typealias Step = (at: Double, run: @MainActor () -> Void)

    /// Текущий прогон: второй сценарий, запущенный поверх первого, не должен мешать его шагам
    private static var current: Task<Void, Never>?

    @discardableResult
    static func run(_ steps: [Step], after delay: Double = 0) -> Task<Void, Never> {
        current?.cancel()
        let task = Task { @MainActor in
            let start = ContinuousClock.now + .milliseconds(Int(delay * 1000))
            for step in steps.sorted(by: { $0.at < $1.at }) {
                try? await Task.sleep(until: start + .milliseconds(Int(step.at * 1000)), clock: .continuous)
                guard !Task.isCancelled else { return }
                step.run()
            }
        }
        current = task
        return task
    }
}
