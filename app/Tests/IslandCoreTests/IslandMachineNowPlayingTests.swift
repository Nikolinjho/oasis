import Testing

@testable import IslandCore

/// Now Playing (ui-inspection 1.8): пауза, Quick Peek, источник на переднем плане. Режим Alcove, темп 1
struct IslandMachineNowPlayingTests {
  static func model(_ surface: Surface = .compact, playing: Bool = true, rules: NowPlayingRules = NowPlayingRules()) -> IslandModel {
    var config = IslandMachine.Config.alcove
    config.nowPlaying = rules
    var model = IslandModel(config: config)
    model.surface = surface
    model.hasMedia = true
    model.isPlaying = playing
    return model
  }

  @Test("Пауза: через Idle duration компакт уходит в форму выреза")
  func pauseGoesIdle() {
    var m = Self.model()
    #expect(IslandMachine.reduce(&m, .playbackChanged(false)) == [.schedule(.mediaIdle, after: .seconds(3))])
    #expect(m.surface == .compact)
    #expect(IslandMachine.reduce(&m, .timerFired(.mediaIdle)) == [.animate(.compactOut)])
    #expect(m.surface == .idle)
    #expect(m.base == .idle)
  }

  @Test("Play до конца Idle duration: компакт остаётся, таймер снят, peek по When media changes")
  func resumeBeforeIdle() {
    var m = Self.model(playing: false)
    #expect(
      IslandMachine.reduce(&m, .playbackChanged(true))
        == [.cancel(.mediaIdle), .animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek)])
    #expect(m.surface == .peek)

    var rules = NowPlayingRules()
    rules.peeksOnPlayback = false
    var quiet = Self.model(playing: false, rules: rules)
    #expect(IslandMachine.reduce(&quiet, .playbackChanged(true)) == [.cancel(.mediaIdle)])
    #expect(quiet.surface == .compact)
  }

  @Test("Play после ухода в вырез: компакт возвращается")
  func resumeFromIdle() {
    var m = Self.model(.compact, playing: false)
    _ = IslandMachine.reduce(&m, .timerFired(.mediaIdle))
    #expect(IslandMachine.reduce(&m, .playbackChanged(true)) == [.cancel(.mediaIdle), .animate(.compactIn)])
    #expect(m.surface == .compact)
  }

  @Test("Трек на паузе без музыки на экране: только запоминается, компакт появляется по play")
  func pausedTrackFromIdle() {
    var m = Self.model(.idle, playing: false)
    m.hasMedia = false
    #expect(IslandMachine.reduce(&m, .pausedTrackChanged).isEmpty)
    #expect(m.surface == .idle)
    #expect(m.mediaIdle)
    #expect(IslandMachine.reduce(&m, .playbackChanged(true)) == [.cancel(.mediaIdle), .animate(.compactIn)])
    #expect(m.surface == .compact)
  }

  @Test("Трек на паузе при компакте: как смена трека, затем таймер Idle duration")
  func pausedTrackFromCompact() {
    var m = Self.model()
    #expect(
      IslandMachine.reduce(&m, .pausedTrackChanged)
        == [.animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek), .schedule(.mediaIdle, after: .seconds(3))])
  }

  @Test("Таймер паузы после возобновления ничего не делает")
  func staleIdleTimer() {
    var m = Self.model(playing: true)
    #expect(IslandMachine.reduce(&m, .timerFired(.mediaIdle)).isEmpty)
    #expect(m.surface == .compact)
  }

  @Test("Quick Peek выключен: смена трека без peek. Peek duration задаёт длительность peek")
  func quickPeek() {
    var rules = NowPlayingRules()
    rules.quickPeek = false
    var off = Self.model(rules: rules)
    #expect(IslandMachine.reduce(&off, .trackChanged).isEmpty)
    #expect(off.surface == .compact)

    var long = NowPlayingRules()
    long.peekDuration = .seconds(4)
    var m = Self.model(rules: long)
    #expect(IslandMachine.reduce(&m, .trackChanged) == [.animate(.peekOpen), .schedule(.peekEnd, after: .seconds(4))])
  }

  @Test("Hide while source app is active: компакт уходит, пока источник на переднем плане")
  func sourceActive() {
    var rules = NowPlayingRules()
    rules.hidesWhileSourceActive = true
    var m = Self.model(rules: rules)
    #expect(IslandMachine.reduce(&m, .sourceActiveChanged(true)) == [.animate(.compactOut)])
    #expect(m.surface == .idle)
    #expect(IslandMachine.reduce(&m, .sourceActiveChanged(false)) == [.animate(.compactIn)])
    #expect(m.surface == .compact)

    var ignoring = Self.model()
    #expect(IslandMachine.reduce(&ignoring, .sourceActiveChanged(true)).isEmpty)
  }

  @Test("Now Playing выключен: новый трек в покое не показывается, смена настройки уводит компакт")
  func disabled() {
    var rules = NowPlayingRules()
    rules.isEnabled = false
    var idle = Self.model(.idle, rules: rules)
    idle.hasMedia = false
    #expect(IslandMachine.reduce(&idle, .trackChanged).isEmpty)
    #expect(idle.surface == .idle)

    var m = Self.model()
    let old = m.base
    m.config.nowPlaying.isEnabled = false
    #expect(IslandMachine.reduce(&m, .baseChanged(from: old)) == [.animate(.compactOut)])
    #expect(m.surface == .idle)

    // то же через настройки целиком (configChanged): машина сама видит смену покоя
    var viaConfig = Self.model()
    var off = viaConfig.config
    off.nowPlaying.isEnabled = false
    #expect(IslandMachine.reduce(&viaConfig, .configChanged(off)) == [.animate(.compactOut)])
    #expect(viaConfig.surface == .idle)
  }
}
