import IslandCore
import Testing
@testable import IslandUI

struct WaveformColorChoiceTests {
    static let accent = RGB(red: 0.9, green: 0.2, blue: 0.1)
    static let bottom = RGB(red: 0.1, green: 0.2, blue: 0.9)

    static func info(accent: RGB? = nil, accentBottom: RGB? = nil) -> NowPlayingInfo {
        NowPlayingInfo(title: "T", isPlaying: true, accent: accent, accentBottom: accentBottom)
    }

    @Test("Monochrome — всегда серый, с обложкой и без")
    func monochrome() {
        #expect(waveformColorChoice(nil, .monochrome) == .monochrome)
        #expect(waveformColorChoice(Self.info(accent: Self.accent), .monochrome) == .monochrome)
    }

    @Test("Colored — цвет обложки, без обложки серый")
    func colored() {
        #expect(waveformColorChoice(nil, .colored) == .colored(nil))
        #expect(waveformColorChoice(Self.info(accent: Self.accent), .colored) == .colored(Self.accent))
    }

    @Test("Gradient — оба цвета обложки, без второго цвета как Colored")
    func gradient() {
        #expect(waveformColorChoice(nil, .gradient) == .colored(nil))
        #expect(waveformColorChoice(Self.info(accent: Self.accent), .gradient) == .colored(Self.accent))
        #expect(waveformColorChoice(Self.info(accent: Self.accent, accentBottom: Self.bottom), .gradient)
            == .gradient(top: Self.accent, bottom: Self.bottom))
    }
}
