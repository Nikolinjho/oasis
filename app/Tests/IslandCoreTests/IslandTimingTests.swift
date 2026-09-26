import Testing
@testable import IslandCore

@Test("Отклик на hover и задержка ухода по кадрам видео Alcove: 130 и 150 мс")
func hoverDelays() {
    #expect(IslandTiming.hoverNudge == .milliseconds(130))
    #expect(IslandTiming.hoverLeave == .milliseconds(150))
}
