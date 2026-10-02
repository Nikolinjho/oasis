import Testing

@testable import IslandCore

struct IslandMachineVolumeRowTests {
  static func player() -> IslandModel {
    var m = IslandModel(config: .alcove)
    m.hasMedia = true
    m.surface = .expanded
    m.expandedView = .player
    return m
  }

  @Test("Кнопка вывода в плеере показывает и прячет строку громкости (Alcove 1.7.9, 28.09)")
  func toggles() {
    var m = Self.player()
    #expect(IslandMachine.reduce(&m, .volumeRowToggled) == [.animate(.volumeRow)])
    #expect(m.volumeRowShown)
    #expect(IslandMachine.reduce(&m, .volumeRowToggled) == [.animate(.volumeRow)])
    #expect(!m.volumeRowShown)
  }

  @Test("Вне плеера строки громкости нет: в Duo событие ничего не делает")
  func onlyInPlayer() {
    var m = Self.player()
    m.expandedView = .duo
    #expect(IslandMachine.reduce(&m, .volumeRowToggled).isEmpty)
    #expect(!m.volumeRowShown)
  }

  @Test("Схлопывание и смена вида сбрасывают строку громкости")
  func resets() {
    var closed = Self.player()
    _ = IslandMachine.reduce(&closed, .volumeRowToggled)
    _ = IslandMachine.reduce(&closed, .clickedOutside)
    #expect(!closed.volumeRowShown)

    var cycled = Self.player()
    _ = IslandMachine.reduce(&cycled, .volumeRowToggled)
    _ = IslandMachine.reduce(&cycled, .expandedViewCycled)
    #expect(!cycled.volumeRowShown)
  }
}
