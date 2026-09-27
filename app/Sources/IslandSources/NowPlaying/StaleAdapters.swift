import Foundation

/// Адаптеры, оставшиеся от прошлых запусков. Приложение убили сигналом или оно упало,
/// applicationWillTerminate не вызвался, и perl усыновил launchd (ppid 1).
/// Процесс другой запущенной сборки не трогаем: у него ppid — живое приложение
public enum StaleAdapters {
    static let marker = "AlcoveAnalog.app/Contents/Resources/mediaremote-adapter.pl"

    /// Строки `ps -axo pid=,ppid=,command=` → pid сирот адаптера из любой нашей сборки
    public static func pids(psOutput: String) -> [pid_t] {
        psOutput.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = pid_t(parts[0]), let ppid = pid_t(parts[1]),
                  ppid == 1, parts[2].contains(marker) else { return nil }
            return pid
        }
    }

    /// Гасит сирот SIGTERM. Возвращает, сколько нашлось
    @discardableResult
    public static func terminate() -> Int {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,ppid=,command="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        do {
            try ps.run()
        } catch {
            return 0
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        let found = pids(psOutput: String(decoding: data, as: UTF8.self))
        for pid in found { kill(pid, SIGTERM) }
        return found.count
    }
}
