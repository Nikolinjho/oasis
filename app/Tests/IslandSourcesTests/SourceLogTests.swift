import Testing
@testable import IslandSources

@Test("Логи пишутся в подсистему приложения")
func logSubsystem() {
    #expect(SourceLog.subsystem == "dev.nikoko.alcove-analog")
}
