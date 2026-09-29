import Testing
@testable import IslandCore

@Test("Отклик на hover и задержка ухода по кадрам видео Alcove: 130 и 150 мс")
func hoverDelays() {
    #expect(IslandTiming.hoverNudge == .milliseconds(130))
    #expect(IslandTiming.hoverLeave == .milliseconds(150))
}

@Test("Движение музыки по записям Alcove: переворот через 130 мс, строка 34 pt/с после 1.1 с, обложка peek ×1.2")
func musicMotion() {
    #expect(IslandTiming.artworkFlipDelay == .milliseconds(130))
    #expect(IslandTiming.marqueeSpeed == 34)
    #expect(IslandTiming.marqueeDelay == 1.1)
    #expect(IslandTiming.peekArtworkScale == 1.2)
}
