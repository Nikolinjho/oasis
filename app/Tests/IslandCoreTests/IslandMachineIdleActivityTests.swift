import Testing

@testable import IslandCore

/// Idle Activity (General, ui-inspection 1.2): какой вид раскрытого открывается
struct IslandMachineIdleActivityTests {
  static func model(_ rules: ExpandedRules, config: IslandMachine.Config = .user, media: Bool = true) -> IslandModel {
    var config = config
    config.expanded = rules
    var model = IslandModel(config: config)
    model.surface = media ? .compact : .idle
    model.hasMedia = media
    return model
  }

  static func rules(_ activity: IdleActivity, mostRecent: Bool = false, force: Bool = true) -> ExpandedRules {
    var rules = ExpandedRules()
    rules.idleActivity = activity
    rules.mostRecent = mostRecent
    rules.forceEnable = force
    return rules
  }

  @Test("Playing и Calendar открывают свой вид")
  func chosenView() {
    var player = Self.model(Self.rules(.playing))
    _ = IslandMachine.reduce(&player, .hoverEntered)
    #expect(player.surface == .expanded && player.expandedView == .player)

    var calendar = Self.model(Self.rules(.calendar))
    _ = IslandMachine.reduce(&calendar, .hoverEntered)
    #expect(calendar.expandedView == .calendar)
  }

  @Test("Playing без музыки: Force enable выкл — Duo, вкл — плеер")
  func forceEnable() {
    var fallback = Self.model(Self.rules(.playing, force: false), media: false)
    _ = IslandMachine.reduce(&fallback, .hoverEntered)
    #expect(fallback.expandedView == .duo)

    var forced = Self.model(Self.rules(.playing, force: true), media: false)
    _ = IslandMachine.reduce(&forced, .hoverEntered)
    #expect(forced.expandedView == .player)
  }

  @Test("Most Recent: следующее раскрытие — последний просмотренный вид")
  func mostRecent() {
    var m = Self.model(Self.rules(.duo, mostRecent: true))
    _ = IslandMachine.reduce(&m, .hoverEntered)
    _ = IslandMachine.reduce(&m, .expandedViewCycled)
    _ = IslandMachine.reduce(&m, .expandedViewCycled)
    #expect(m.expandedView == .calendar)
    _ = IslandMachine.reduce(&m, .clickedOutside)
    _ = IslandMachine.reduce(&m, .hoverEntered)
    #expect(m.surface == .expanded && m.expandedView == .calendar)
  }

  @Test("None: hover — только отклик без таймера раскрытия, клик не раскрывает")
  func none() {
    var m = Self.model(Self.rules(.none))
    let fx = IslandMachine.reduce(&m, .hoverEntered)
    #expect(m.surface == .hoverNudge(from: .compact))
    #expect(!fx.contains { if case .schedule(.hoverOpen, _) = $0 { true } else { false } })
    #expect(IslandMachine.reduce(&m, .clicked).isEmpty)
    #expect(m.surface == .hoverNudge(from: .compact))

    var alcove = Self.model(Self.rules(.none), config: .alcove)
    #expect(IslandMachine.reduce(&alcove, .clicked).isEmpty)
    #expect(alcove.surface == .compact)
  }

  @Test("Hover duration > 0: сначала отклик, раскрытие по таймеру hoverOpen — выбранный вид")
  func hoverDelayOpensChosenView() {
    let config = IslandMachine.Config.user.applying(expandOnHover: true, hoverDuration: 0.3)
    var m = Self.model(Self.rules(.calendar), config: config, media: false)
    let fx = IslandMachine.reduce(&m, .hoverEntered)
    #expect(m.surface == .hoverNudge(from: .idle))
    #expect(fx.contains { if case .schedule(.hoverOpen, _) = $0 { true } else { false } })
    _ = IslandMachine.reduce(&m, .timerFired(.hoverOpen))
    #expect(m.surface == .expanded && m.expandedView == .calendar)
  }

  @Test("Клик из компакта с музыкой при Playing открывает плеер")
  func clickFromCompactWithPlaying() {
    var m = Self.model(Self.rules(.playing))
    #expect(m.surface == .compact)
    _ = IslandMachine.reduce(&m, .clicked)
    #expect(m.surface == .expanded && m.expandedView == .player)
  }

  @Test("Idle Activity переключили на None, пока таймер hoverOpen ждал: раскрытия не будет")
  func noneWhileHoverOpenPending() {
    let config = IslandMachine.Config.user.applying(expandOnHover: true, hoverDuration: 0.3)
    var m = Self.model(Self.rules(.duo), config: config, media: false)
    _ = IslandMachine.reduce(&m, .hoverEntered)
    #expect(m.surface == .hoverNudge(from: .idle))
    // настройку переключили на None, пока таймер уже стоял в очереди
    m.config.expanded.idleActivity = .none
    let fx = IslandMachine.reduce(&m, .timerFired(.hoverOpen))
    #expect(fx.isEmpty)
    #expect(m.surface == .hoverNudge(from: .idle))
  }
}
