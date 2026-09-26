import Testing
@testable import IslandCore

@Test("Сжатие перед сменой активности короче схлопывания")
func shrinkIsShorterThanCollapse() {
    #expect(IslandTiming.shrink < IslandTiming.collapse)
}
