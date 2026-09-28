import AppKit
import IslandCore
import os

/// Звуки уведомлений из Contents/Resources/Sounds. Файлы — из бандла Alcove (assets/sounds),
/// только для локальной сборки: bundle.sh копирует их, если папка есть
@MainActor
final class SoundPlayer {
    private var cache: [IslandSound: NSSound] = [:]
    private let log = Logger(subsystem: "dev.nikoko.alcove-analog", category: "sound")

    nonisolated static func url(for sound: IslandSound, resources: URL) -> URL {
        resources.appendingPathComponent("Sounds").appendingPathComponent("\(sound.rawValue).caf")
    }

    func play(_ sound: IslandSound) {
        if let cached = cache[sound] {
            cached.stop()
            cached.play()
            return
        }
        guard let resources = Bundle.main.resourceURL,
              let player = NSSound(contentsOf: Self.url(for: sound, resources: resources), byReference: true)
        else {
            log.error("sound \(sound.rawValue, privacy: .public) not found in bundle")
            return
        }
        cache[sound] = player
        player.play()
    }
}
