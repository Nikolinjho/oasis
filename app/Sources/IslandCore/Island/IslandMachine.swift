/// Таймеры машины. Новый schedule с тем же id отменяет прежний
public enum TimerID: Hashable, Sendable {
  case peekEnd, hudHide, grow
  /// Отклик на hover раскрывается в плеер
  case hoverOpen
  /// Курсор ушёл из раскрытого: схлопывание с задержкой
  case hoverLeave
  /// Уведомление отслужило свой срок
  case alertHide
  /// Peek календаря на старте события отслужил свой срок
  case calendarPeekEnd
  /// Музыка на паузе дольше Idle duration
  case mediaIdle
}

public enum IslandEvent: Equatable, Sendable {
  case trackChanged
  /// Новый трек пришёл уже на паузе: запуск, приложение открыто на паузе, смена трека на паузе
  case pausedTrackChanged
  case mediaCleared
  case hudChanged(HUDKind, level: Double)
  case alertArrived(IslandAlert)
  /// Уведомление этого вида больше не нужно (Dismiss Event): ждущие в очереди уходят. Показанное уходит сразу,
  /// как по alertHide, а сжатие к нему идёт к следующему из очереди или в покой
  case alertRetracted(IslandAlert.Kind)
  /// Открылось или закрылось окно календаря: от liveLead (15 минут) до начала события до его конца
  case calendarLiveChanged(Bool)
  /// Событие началось: peek с названием поверх компакта календаря и звук
  case calendarStarted
  /// Свайп вниз по раскрытому: следующий вид
  case expandedViewCycled
  /// Свайп вверх по компакту: активность уходит в форму выреза до смены активности или свайпа вниз
  case activityDismissed
  /// Свайп вниз по форме выреза: убранная активность возвращается
  case activityRestored
  /// Клик по кнопке вывода в раскрытом плеере: строка громкости под кнопками (Alcove 1.7.9, 28.09)
  case volumeRowToggled
  /// Ползунок Notch width/height в General → Tuning зажат (значение) или отпущен (nil), Task 17t:
  /// как уведомление, только без звука и очереди — держит подсказку, пока кнопка мыши на ползунке
  case tuningHintChanged(TuningHint?)
  case hoverEntered, hoverExited
  case clicked, clickedOutside
  /// На экране с вырезом открылось или закрылось полноэкранное приложение
  case fullscreenChanged(Bool)
  /// Музыка заиграла или встала на паузу. Смена трека — trackChanged, он сам считает трек играющим
  case playbackChanged(Bool)
  /// Приложение-источник музыки на переднем плане (Hide while source app is active)
  case sourceActiveChanged(Bool)
  /// Покой мог смениться без события машины (настройки): from — покой до смены
  case baseChanged(from: Surface)
  /// Новые настройки машины: смена покоя и перестройка компакта календаря под музыку идут пружиной, как от событий
  case configChanged(IslandMachine.Config)
  case timerFired(TimerID)
}

public enum IslandEffect: Equatable, Sendable {
  case animate(IslandTransition)
  case schedule(TimerID, after: Duration)
  case cancel(TimerID)
  /// Звук уведомления: играет store, если звуки включены в настройках
  case play(IslandSound)
}

public struct IslandModel: Equatable, Sendable {
  public var config: IslandMachine.Config
  public var surface: Surface = .idle
  public var hasMedia = false
  /// Куда остров раскроется, когда закончится сжатие
  public var pending: Surface?
  /// На экране с вырезом полноэкранное приложение: живые активности (музыка, календарь) в покое не показываются
  public var isFullscreen = false
  /// Курсор ушёл из раскрытого (режим пользователя): ждём таймер hoverLeave, возврат его отменяет
  public var leaving = false
  /// Уведомления ждут конца HUD или текущего уведомления: по приоритету, при равном — по приходу
  public var alertQueue: [IslandAlert] = []
  /// Виды уведомлений, которые HUD вытеснил с экрана и вернул в очередь: их звук уже прозвучал,
  /// повторный показ после HUD идёт без звука. Новое уведомление того же вида и отзыв снимают отметку
  public var heardAlerts: Set<IslandAlert.Kind> = []
  /// Открыто окно календаря (за 15 минут до начала (liveLead) … конец события): без музыки компакт календаря
  /// вытесняет покой, при играющей музыке он и есть компакт музыки (Alcove 1.7.9, 29.09)
  public var calendarLive = false
  /// Вид раскрытого. С чего начинается раскрытие, решает Idle Activity (ExpandedRules)
  public var expandedView: ExpandedView = .duo
  /// Последний просмотренный вид раскрытого: для Most Recent
  public var lastExpandedView: ExpandedView = .duo
  /// Строка громкости под кнопками плеера: остров выше на IslandGeometry.volumeRowHeight.
  /// Живёт только в раскрытом плеере: уход из него сбрасывает её (reduce)
  public var volumeRowShown = false
  /// Музыка играет. Трек на паузе держит компакт Idle duration (NowPlayingRules.idleDelay)
  public var isPlaying = false
  /// Пауза длится дольше Idle duration: компакт музыки не показывается
  public var mediaIdle = false
  /// Приложение-источник на переднем плане
  public var sourceActive = false
  /// Активность убрана свайпом (Swipe to dismiss activity): покой — форма выреза. Снимается новой активностью
  public var dismissed = false

  public init(config: IslandMachine.Config = .user) {
    self.config = config
  }

  /// Состояние покоя. Календарь важнее музыки. В полноэкранном, без compactAtRest и убранной свайпом
  /// активности — форма выреза
  public var base: Surface {
    guard config.compactAtRest, !isFullscreen, !dismissed else { return .idle }
    if calendarLive { return .calendar }
    return showsMedia ? .compact : .idle
  }

  /// Музыка в покое: трек есть, Now Playing включён, пауза не дольше Idle duration, источник не на переднем плане
  public var showsMedia: Bool {
    let rules = config.nowPlaying
    return hasMedia && rules.isEnabled && !mediaIdle && !(rules.hidesWhileSourceActive && sourceActive)
  }

  /// Повтор того же вида заменяет ждущее
  mutating func enqueue(_ alert: IslandAlert) {
    alertQueue.removeAll { $0.kind == alert.kind }
    let index = alertQueue.firstIndex { $0.priority < alert.priority } ?? alertQueue.endIndex
    alertQueue.insert(alert, at: index)
  }

  /// HUD вытеснил уведомление (показанное или то, к которому шло сжатие). Приоритет 2 и выше (напоминание
  /// календаря, Low Battery) возвращается в очередь и покажется после HUD, остальные пропадают, как в P0
  /// (решение по ревью P1). heard — звук уже прозвучал: повторный показ без него
  mutating func displaceByHUD(_ alert: IslandAlert, heard: Bool) {
    guard alert.priority >= 2 else { return }
    // показанное уведомление всегда одно своего вида: ждущее того же вида обновило бы показанное, а не встало в очередь
    assert(!heard || !alertQueue.contains { $0.kind == alert.kind })
    enqueue(alert)
    if heard { heardAlerts.insert(alert.kind) }
  }

  mutating func dequeueAlert() -> IslandAlert? {
    alertQueue.isEmpty ? nil : alertQueue.removeFirst()
  }
}

/// Чистая машина состояний острова: приоритеты и хореография смены активностей.
/// Приоритет: HUD > уведомления > раскрытый (Duo/плеер) > hover и отклик на него > peek > компакт календаря > компакт музыки > покой
public enum IslandMachine {  // swiftlint:disable:this type_body_length - редьюсер машины, разбивка вне задачи
  /// Поведение, которое отличает наш режим от Alcove. Эталон сверки записан
  /// в режиме Alcove, поэтому оба поведения — настройка, а не замена
  public struct Config: Equatable, Sendable {
    /// Hover сразу раскрывает expanded (по умолчанию — Duo, полный плеер по свайпу). Выключено:
    /// hover даёт мини-состояние, раскрытие — по клику
    public var hoverOpensPlayer: Bool
    /// При живой активности (музыка, окно календаря) остров стоит в компакте. Выключено: компакт
    /// только на время peek, в покое форма выреза. Компакт и peek календаря при этом не показываются вовсе
    public var compactAtRest: Bool

    /// Во сколько раз анимации острова медленнее замеров Alcove: пружины (IslandMotion) и таймеры,
    /// привязанные к их длине (сжатие перед grow). Характер пружины (ζ) тот же
    public var timeScale: Double
    /// Hover duration Alcove (0…0.6 с): сколько курсор держится над островом до раскрытия.
    /// Ноль — плеер сразу, без промежуточного отклика: так у нативного Alcove по умолчанию.
    /// Ненулевая задержка — отклик hoverNudge на это время. Замедляется timeScale
    public var hoverDelay: Duration
    /// Expand on hover (General). Выключено: hover даёт только отклик без таймера, раскрывает клик.
    /// Так ведёт себя Alcove 1.7.7 (ui-inspection 3.4, «Hover при Expand on hover = выкл»)
    public var expandsOnHover: Bool
    /// Battery и Connectivity: длительность и звук уведомлений
    public var alerts = AlertRules()
    /// Display / Sound → Duration: 1, 1.5 или 2 с (ui-inspection 1.6, 1.7)
    public var hudDurations = HUDDurations()
    /// Now Playing: пауза, Quick Peek, источник на переднем плане
    public var nowPlaying = NowPlayingRules()
    /// Idle Activity (General): какой вид открывается раскрытием
    public var expanded = ExpandedRules()

    public init(
      hoverOpensPlayer: Bool, compactAtRest: Bool, timeScale: Double = 1, hoverDelay: Duration = .zero,
      expandsOnHover: Bool = true
    ) {
      self.hoverOpensPlayer = hoverOpensPlayer
      self.compactAtRest = compactAtRest
      self.timeScale = timeScale
      self.hoverDelay = hoverDelay
      self.expandsOnHover = expandsOnHover
    }

    /// Настройки General: Expand on hover и Hover duration (0…0.6 с, шаг 0.1 в окне настроек)
    public func applying(expandOnHover: Bool, hoverDuration: Double) -> Config {
      var config = self
      config.expandsOnHover = expandOnHover
      // NaN/inf не проходят Int(): читаем как 0, а не роняем машину настройками из UI
      let duration = hoverDuration.isFinite ? hoverDuration : 0
      config.hoverDelay = .milliseconds(Int((min(max(duration, 0), 0.6) * 1000).rounded()))
      return config
    }

    /// Режим пользователя: hover раскрывает остров, при живой активности в покое компакт, как у Alcove.
    /// Покой в форме выреза пробовали и отказались: остаётся настройкой compactAtRest = false.
    /// Анимации на 18% медленнее Alcove: по живой проверке замеренные казались слишком быстрыми
    public static let user = Config(hoverOpensPlayer: true, compactAtRest: true, timeScale: 1.18)
    /// Поведение Alcove, с которым записан эталон: для demo-прогона и сверки, пружины как в замерах
    public static let alcove = Config(hoverOpensPlayer: false, compactAtRest: true)
  }

  public static func reduce(_ model: inout IslandModel, _ event: IslandEvent) -> [IslandEffect] {
    let showedMedia = model.showsMedia
    var effects = reduceEvent(&model, event)
    // строка громкости есть только в раскрытом плеере. У Alcove после схлопывания и нового раскрытия
    // её нет (28.09). Сброс при смене вида свайпом — оценка: не проверяли
    if model.surface != .expanded || model.expandedView != .player { model.volumeRowShown = false }
    // музыка появилась или пропала во время окна календаря, а обработчик события не менял surface
    // (calendarLiveChanged ждёт смены base, а calendar приоритетнее музыки в base независимо от неё):
    // компакт/peek меняют размер на месте, без этого — мгновенный скачок ширины без анимации.
    // Отклик hover над компактом календаря рисует тот же компакт, только шире: туда же
    if isCalendarRest(unwrapHoverNudge(model.surface)), showedMedia != model.showsMedia,
      !effects.contains(where: { if case .animate = $0 { true } else { false } })
    {
      effects.append(.animate(.calendarRestyle))
    }
    return effects
  }

  // swiftlint:disable:next cyclomatic_complexity - плоская таблица событие → обработчик, по case на событие
  private static func reduceEvent(_ model: inout IslandModel, _ event: IslandEvent) -> [IslandEffect] {
    switch event {
    case .trackChanged: trackChanged(&model)
    case .pausedTrackChanged: pausedTrackChanged(&model)
    case .mediaCleared: mediaCleared(&model)
    case .hudChanged(let kind, let level): hudChanged(&model, .hud(kind, level: level))
    case .alertArrived(let alert): alertArrived(&model, alert)
    case .alertRetracted(let kind): alertRetracted(&model, kind)
    case .calendarLiveChanged(let live): calendarLiveChanged(&model, live)
    case .calendarStarted: calendarStarted(&model)
    case .expandedViewCycled: expandedViewCycled(&model)
    case .activityDismissed: activityDismissed(&model)
    case .activityRestored: activityRestored(&model)
    case .volumeRowToggled: volumeRowToggled(&model)
    case .tuningHintChanged(let hint): tuningHintChanged(&model, hint)
    case .hoverEntered:
      // мини-hover режима Alcove — ступень к раскрытию: при Idle Activity None раскрывать нечего, его нет
      model.config.hoverOpensPlayer
        ? nudge(&model) : openingView(model) == nil ? [] : open(&model, to: .hover, with: .hoverOpen)
    case .clicked: open(&model, to: .expanded, with: .expand)
    case .hoverExited: model.config.hoverOpensPlayer ? leave(&model) : close(&model)
    case .clickedOutside: close(&model)
    case .fullscreenChanged(let on): fullscreenChanged(&model, on)
    case .playbackChanged(let playing): playbackChanged(&model, playing)
    case .sourceActiveChanged(let active): sourceActiveChanged(&model, active)
    case .baseChanged(let old): baseChanged(&model, from: old)
    case .configChanged(let config): configChanged(&model, config)
    case .timerFired(let id): timerFired(&model, id)
    }
  }

  /// Компакт или peek календаря: их размер зависит от музыки (calendarWithMusic)
  private static func isCalendarRest(_ surface: Surface) -> Bool {
    surface == .calendar || surface == .calendarPeek
  }

  /// Покой: форма выреза, компакт музыки или календаря. После сжатия к покою цель пересчитывается по base
  private static func isRest(_ surface: Surface) -> Bool {
    surface == .idle || surface == .compact || surface == .calendar
  }

  private static func trackChanged(_ m: inout IslandModel) -> [IslandEffect] {
    // новый трек — активность, которую свайпом уже не удержать в вырезе
    m.dismissed = false
    m.hasMedia = true
    // новый трек — снова активность: пауза до него не в счёт. Если он на паузе, store пришлёт playbackChanged(false)
    m.isPlaying = true
    m.mediaIdle = false
    // после сжатия остров вернётся в покой, а покой зависит от музыки
    if let pending = m.pending, isRest(pending) { m.pending = m.base }
    let rules = m.config.nowPlaying
    switch m.surface {
    case .idle where m.isFullscreen:
      // в полноэкранном музыка только запоминается: компакт появится после выхода
      return []
    case .idle where m.pending == nil && m.config.compactAtRest:
      // Now Playing выключен, источник на переднем плане или обеих активностей не осталось: трек
      // только запоминается. Идём в base, а не сразу в .compact — если островом свайпом убрали
      // активность во время открытого окна календаря (dismissed), новый трек его снял выше,
      // и base мог остаться .calendar: компакт без бейджа календаря потерял бы окно на весь его остаток
      guard m.base != .idle else { return [] }
      m.surface = m.base
      return [.animate(.compactIn)]
    case .idle where m.pending == nil:
      // без компакта в покое смена трека коротко показывает peek и уходит обратно в форму выреза
      guard m.showsMedia, rules.quickPeek else { return [] }
      m.surface = .peek
      return [.animate(.peekOpen), .schedule(.peekEnd, after: rules.peekDuration)]
    case .compact where m.pending == nil:
      guard rules.quickPeek else { return [] }
      m.surface = .peek
      return [.animate(.peekOpen), .schedule(.peekEnd, after: rules.peekDuration)]
    default:
      // peek не перезапускаем. При компакте календаря и в остальных состояниях меняется только контент
      return []
    }
  }

  /// Трек на паузе. Музыка на экране (компакт, Idle duration ещё идёт) — как смена трека, затем пауза.
  /// Музыки не было или пауза уже увела её в вырез — трек только запоминается, компакт появится по play
  private static func pausedTrackChanged(_ m: inout IslandModel) -> [IslandEffect] {
    guard !m.hasMedia || m.mediaIdle else { return trackChanged(&m) + playbackChanged(&m, false) }
    m.hasMedia = true
    m.isPlaying = false
    m.mediaIdle = true
    return []
  }

  /// В полноэкранном компакты и peek прячутся, открытый остров и HUD не трогаем:
  /// они закроются в покой, который теперь форма выреза
  private static func fullscreenChanged(_ m: inout IslandModel, _ on: Bool) -> [IslandEffect] {
    guard m.isFullscreen != on else { return [] }
    m.isFullscreen = on
    if let pending = m.pending, isRest(pending) { m.pending = m.base }
    switch m.surface {
    case .compact where on, .peek where on:
      m.surface = .idle
      return [.cancel(.peekEnd), .animate(.compactOut)]
    case .calendar where on, .calendarPeek where on:
      m.surface = .idle
      return [.cancel(.calendarPeekEnd), .animate(.compactOut)]
    case .idle where !on && m.pending == nil && m.base != .idle:
      m.surface = m.base
      return [.animate(.compactIn)]
    default:
      return []
    }
  }

  private static func mediaCleared(_ m: inout IslandModel) -> [IslandEffect] {
    m.hasMedia = false
    m.isPlaying = false
    m.mediaIdle = false
    // музыки больше нет: если и календарь не живёт, прятать больше нечего — флаг не должен пережить
    // обе активности разом (review Task 15)
    if !m.calendarLive { m.dismissed = false }
    if let pending = m.pending, isRest(pending) { m.pending = m.base }
    switch m.surface {
    case .compact, .peek:
      m.surface = .idle
      return [.cancel(.peekEnd), .animate(.compactOut)]
    default:
      return []
    }
  }

  /// Пауза ставит таймер Idle duration, play снимает его. Play после ухода в вырез возвращает компакт,
  /// play в компакте — peek (When media changes)
  private static func playbackChanged(_ m: inout IslandModel, _ playing: Bool) -> [IslandEffect] {
    guard m.hasMedia, m.isPlaying != playing else { return [] }
    m.isPlaying = playing
    guard playing else { return [.schedule(.mediaIdle, after: m.config.nowPlaying.idleDelay)] }
    let old = m.base
    let wasIdle = m.mediaIdle
    m.mediaIdle = false
    if wasIdle { return [.cancel(.mediaIdle)] + baseChanged(&m, from: old) }
    let rules = m.config.nowPlaying
    guard m.surface == .compact, m.pending == nil, rules.quickPeek, rules.peeksOnPlayback else { return [.cancel(.mediaIdle)] }
    m.surface = .peek
    return [.cancel(.mediaIdle), .animate(.peekOpen), .schedule(.peekEnd, after: rules.peekDuration)]
  }

  private static func sourceActiveChanged(_ m: inout IslandModel, _ active: Bool) -> [IslandEffect] {
    guard m.sourceActive != active else { return [] }
    let old = m.base
    m.sourceActive = active
    return baseChanged(&m, from: old)
  }

  /// Покой сменился не из-за трека и не из-за календаря: пауза дольше Idle duration, источник на переднем плане,
  /// настройки, свайп по компакту. Остров в прежнем покое переходит в новый, как при смене окна календаря.
  /// Peek в новом покое «форма выреза» уходит сразу, его таймер снимается
  private static func baseChanged(_ m: inout IslandModel, from old: Surface) -> [IslandEffect] {
    if let pending = m.pending, isRest(pending) { m.pending = m.base }
    guard old != m.base, m.pending == nil else { return [] }
    switch m.surface {
    case .peek where m.base == .idle:
      m.surface = .idle
      return [.cancel(.peekEnd), .animate(.compactOut)]
    case .calendarPeek where m.base == .idle:
      m.surface = .idle
      return [.cancel(.calendarPeekEnd), .animate(.compactOut)]
    case _ where m.surface == old:
      return rest(&m, from: old)
    default:
      return []
    }
  }

  /// Новые настройки: покой мог смениться (Now Playing выключен) — как baseChanged. Компакт календаря,
  /// у которого сменилась только музыка, перестраивает reduce (calendarRestyle)
  private static func configChanged(_ m: inout IslandModel, _ config: Config) -> [IslandEffect] {
    let old = m.base
    m.config = config
    return baseChanged(&m, from: old)
  }

  // swiftlint:disable:next cyclomatic_complexity - по case на поверхность, разбивка спрячет порядок проверок
  private static func hudChanged(_ m: inout IslandModel, _ hud: Surface) -> [IslandEffect] {
    if case .hoverNudge(let from) = m.surface {
      // раскрытие отменяется, HUD приходит как из исходного состояния
      m.surface = from
      return [.cancel(.hoverOpen)] + hudChanged(&m, hud)
    }
    if m.leaving {
      m.leaving = false
      return [.cancel(.hoverLeave)] + hudChanged(&m, hud)
    }
    if m.pending != nil {
      // идёт сжатие: HUD покажется, когда оно закончится. Если сжатие шло к уведомлению, HUD его вытесняет:
      // важное возвращается в очередь, остальное пропадает (displaceByHUD)
      if case .alert(let alert) = m.pending { m.displaceByHUD(alert, heard: false) }
      m.pending = hud
      return []
    }
    switch m.surface {
    case .hud:
      m.surface = hud
      return [.animate(.hudUpdate), .schedule(.hudHide, after: hudVisible(m, hud))]
    case .idle:
      m.surface = hud
      return [.animate(.hudIn), .schedule(.hudHide, after: hudVisible(m, hud))]
    // HUD важнее уведомления: уведомление уходит через сжатие, важное вернётся после HUD (displaceByHUD)
    case .alert(let alert):
      m.displaceByHUD(alert, heard: true)
      return shrink(&m, then: hud)
    // подложка подгонки (Task 17t) тоже уступает HUD: не проверялось, ведём как компакт/peek — через сжатие
    case .compact, .peek, .calendar, .calendarPeek, .tuning:
      return shrink(&m, then: hud)
    case .hover, .expanded:
      // раскрытый морфится прямо в HUD, без схлопывания и сжатия (осмотр нативного Alcove 26.09).
      // После HUD раскрытый не возвращается: hudHide уводит в покой
      m.surface = hud
      return [.animate(.hudMorph), .schedule(.hudHide, after: hudVisible(m, hud))]
    case .shrink:
      m.pending = hud
      return []
    case .hoverNudge:
      return []
    }
  }

  /// Длительность HUD по виду: surface — сам HUD, иначе значение по умолчанию
  private static func hudVisible(_ m: IslandModel, _ hud: Surface) -> Duration {
    guard case .hud(let kind, _) = hud else { return IslandTiming.hudVisible }
    return m.config.hudDurations.duration(for: kind)
  }

  /// Уведомление: из покоя сразу, из компакта через сжатие, из раскрытого морфом, как HUD (решение 27.09).
  /// Во время HUD и уведомления другого вида ждёт в очереди. Тот же вид обновляет показанное и продлевает его
  private static func alertArrived(  // swiftlint:disable:this cyclomatic_complexity - по case на поверхность
    _ m: inout IslandModel, _ alert: IslandAlert
  ) -> [IslandEffect] {
    // уведомление — активность, которую свайпом уже не удержать в вырезе
    m.dismissed = false
    // новое уведомление вида, вытесненного HUD, — новый показ со звуком
    m.heardAlerts.remove(alert.kind)
    if case .hoverNudge(let from) = m.surface {
      m.surface = from
      return [.cancel(.hoverOpen)] + alertArrived(&m, alert)
    }
    if m.leaving {
      m.leaving = false
      return [.cancel(.hoverLeave)] + alertArrived(&m, alert)
    }
    if let pending = m.pending {
      switch pending {
      case .hud:
        m.enqueue(alert)
      case .alert(let next) where next.kind != alert.kind:
        // сжатие уже идёт к другому уведомлению: новое ждёт своей очереди
        m.enqueue(alert)
      default:
        m.pending = .alert(alert)
      }
      return []
    }
    switch m.surface {
    case .idle:
      m.surface = .alert(alert)
      return [.animate(.alertIn)] + shown(&m, alert)
    case .alert(let current) where current.kind == alert.kind:
      m.surface = .alert(alert)
      return [.animate(.alertUpdate), .schedule(.alertHide, after: m.config.alerts.duration(for: alert))]
    case .alert, .hud:
      m.enqueue(alert)
      return []
    // подложка подгонки (Task 17t) тоже уступает уведомлению: не проверялось, ведём как компакт/peek
    case .compact, .peek, .calendar, .calendarPeek, .tuning:
      return shrink(&m, then: .alert(alert))
    case .hover, .expanded:
      m.surface = .alert(alert)
      return [.animate(.hudMorph)] + shown(&m, alert)
    case .shrink, .hoverNudge:
      // сжатие всегда с pending, отклик разобран выше
      return []
    }
  }

  private static func alertRetracted(_ m: inout IslandModel, _ kind: IslandAlert.Kind) -> [IslandEffect] {
    m.alertQueue.removeAll { $0.kind == kind }
    m.heardAlerts.remove(kind)
    // сжатие уже идёт к отозванному: иначе после Dismiss оно раскрылось бы со звуком. Цель — как у alertHide:
    // следующее из очереди, иначе покой. Таймер grow уже стоит, эффектов не нужно
    if case .alert(let pending) = m.pending, pending.kind == kind {
      m.pending = m.dequeueAlert().map(Surface.alert) ?? m.base
    }
    // показанное уходит сразу: иначе его вытеснил бы HUD и вернул в очередь (displaceByHUD)
    if case .alert(let shown) = m.surface, shown.kind == kind, m.pending == nil {
      return [.cancel(.alertHide)] + hideAlert(&m)
    }
    return []
  }

  /// Уведомление появилось на экране: таймер ухода и звук
  /// Уже звучавшее и вытесненное HUD (heardAlerts) показывается без звука
  private static func shown(_ m: inout IslandModel, _ alert: IslandAlert) -> [IslandEffect] {
    let heard = m.heardAlerts.remove(alert.kind) != nil
    let sound = heard ? nil : m.config.alerts.sound(for: alert)
    return [.schedule(.alertHide, after: m.config.alerts.duration(for: alert))]
      + (sound.map { [IslandEffect.play($0)] } ?? [])
  }

  /// Окно календаря открылось или закрылось. Остров в покое переходит в новый покой: из формы выреза —
  /// раскрытием, из компакта музыки — через сжатие. Раскрытый, HUD и уведомления вернутся в новый покой сами
  private static func calendarLiveChanged(_ m: inout IslandModel, _ live: Bool) -> [IslandEffect] {
    guard m.calendarLive != live else { return [] }
    let old = m.base
    // окно календаря открылось — убранная свайпом активность возвращается
    if live { m.dismissed = false }
    m.calendarLive = live
    // календарь закрылся и музыки на экране нет — прятать больше нечего (review Task 15)
    if !live, !m.showsMedia { m.dismissed = false }
    if let pending = m.pending, isRest(pending) { m.pending = m.base }
    guard old != m.base, m.pending == nil else { return [] }
    switch m.surface {
    case .calendarPeek where !live:
      // событие кончилось во время peek: сразу в новый покой. Таймер снят здесь, дальше peek
      // считается компактом календаря: shrink и rest не отменят его второй раз
      m.surface = .calendar
      return [.cancel(.calendarPeekEnd)] + rest(&m, from: .calendar)
    case _ where m.surface == old:
      return rest(&m, from: old)
    case .peek where live:
      // peek музыки прерывается: календарь важнее
      return shrink(&m, then: .calendar)
    default:
      return []
    }
  }

  /// Переход между двумя покоями: из формы выреза и в неё — напрямую, между компактами — через сжатие
  private static func rest(_ m: inout IslandModel, from old: Surface) -> [IslandEffect] {
    let new = m.base
    switch (old, new) {
    case (.idle, _):
      m.surface = new
      return [.animate(.compactIn)]
    case (_, .idle):
      m.surface = .idle
      return [.animate(.compactOut)]
    default:
      return shrink(&m, then: new)
    }
  }

  /// Звук на старте события играет всегда (Play sound on calendar event), peek — только из компакта календаря.
  /// Во время HUD, сжатия и раскрытого — только звук. Вживую окно открывается за 15 минут до старта (liveLead),
  /// и сжатие к календарю к этому времени давно закончилось: сюда попадает разве что отладочная кнопка calendar.start
  private static func calendarStarted(_ m: inout IslandModel) -> [IslandEffect] {
    guard m.surface == .calendar, m.pending == nil else { return [.play(.event)] }
    m.surface = .calendarPeek
    return [.animate(.calendarPeekOpen), .schedule(.calendarPeekEnd, after: IslandTiming.calendarPeek), .play(.event)]
  }

  /// Следующий вид раскрытого по кругу. Форма та же, меняется только контент.
  /// Плеер в цикле и без музыки: пропускает ли его Alcove, эталона нет (ui-inspection 3.7, «Не проверено»)
  private static func expandedViewCycled(_ m: inout IslandModel) -> [IslandEffect] {
    guard m.surface == .expanded else { return [] }
    m.expandedView = m.expandedView.next
    m.lastExpandedView = m.expandedView
    return [.animate(.viewSwap)]
  }

  /// Поверхность под откликом hover, если сейчас отклик: то, что реально проверяют
  /// activityDismissed/activityRestored перед тем, как его развернуть
  private static func unwrapHoverNudge(_ surface: Surface) -> Surface {
    if case .hoverNudge(let from) = surface { return from }
    return surface
  }

  /// Свайп вверх убирает именно эти поверхности покоя. Компакт и peek календаря — туда же, что и музыка
  private static func isDismissible(_ surface: Surface) -> Bool {
    switch surface {
    case .compact, .peek, .calendar, .calendarPeek: true
    default: false
    }
  }

  /// Свайп вверх по компакту, peek или компакту календаря: активность уходит в форму выреза.
  /// Есть ли что убирать, проверяется до разворота отклика hover — иначе свайп без активности
  /// заодно закрывал бы отклик и снимал его таймер, хотя внешне ничего не изменилось (review Task 15)
  private static func activityDismissed(_ m: inout IslandModel) -> [IslandEffect] {
    let surface = unwrapHoverNudge(m.surface)
    guard !m.dismissed, m.pending == nil, m.base != .idle, isDismissible(surface) else { return [] }
    var effects: [IslandEffect] = []
    if case .hoverNudge = m.surface {
      m.surface = surface
      effects.append(.cancel(.hoverOpen))
    }
    let old = m.base
    m.dismissed = true
    return effects + baseChanged(&m, from: old)
  }

  /// Свайп вниз по форме выреза: убранная активность возвращается. Отклик hover разворачивается
  /// тем же путём, что и при уборке — иначе base вернётся, а surface останется в hoverNudge
  /// поверх уже неактуального выреза, и baseChanged не увидит смены (review Task 15)
  private static func activityRestored(_ m: inout IslandModel) -> [IslandEffect] {
    guard m.dismissed else { return [] }
    var effects: [IslandEffect] = []
    if case .hoverNudge(let from) = m.surface {
      m.surface = from
      effects.append(.cancel(.hoverOpen))
    }
    let old = m.base
    m.dismissed = false
    return effects + baseChanged(&m, from: old)
  }

  /// Строка громкости: форма растёт или сжимается на 32 pt, контент тот же
  private static func volumeRowToggled(_ m: inout IslandModel) -> [IslandEffect] {
    guard m.surface == .expanded, m.expandedView == .player else { return [] }
    m.volumeRowShown.toggle()
    return [.animate(.volumeRow)]
  }

  /// Подложка подгонки выреза (Task 17t): пока ползунок Tuning зажат, остров показывает подсказку
  /// вместо чего угодно, что было на экране — как HUD/уведомление, но без звука и очереди.
  /// nil (отпустили ползунок) — tuningReleased. Отклик и уход курсора разворачиваются так же, как у HUD:
  /// раскрытие подсказки — то, что реально происходит, а не промежуточное состояние
  private static func tuningHintChanged(  // swiftlint:disable:this cyclomatic_complexity - по case на поверхность
    _ m: inout IslandModel, _ hint: TuningHint?
  ) -> [IslandEffect] {
    guard let hint else { return tuningReleased(&m) }
    if case .hoverNudge(let from) = m.surface {
      m.surface = from
      return [.cancel(.hoverOpen)] + tuningHintChanged(&m, hint)
    }
    if m.leaving {
      m.leaving = false
      return [.cancel(.hoverLeave)] + tuningHintChanged(&m, hint)
    }
    if m.pending != nil {
      // сжатие уже идёт: подсказка становится его целью. Уведомление, к которому оно шло, — в очередь,
      // как при вытеснении HUD (displaceByHUD), звук ещё не звучал
      if case .alert(let alert) = m.pending { m.displaceByHUD(alert, heard: false) }
      m.pending = .tuning(hint)
      return []
    }
    switch m.surface {
    case .tuning(let current) where current == hint:
      return []
    case .tuning:
      m.surface = .tuning(hint)
      return [.animate(.tuningUpdate)]
    case .idle:
      m.surface = .tuning(hint)
      return [.animate(.tuningIn)]
    case .compact, .peek, .calendar, .calendarPeek:
      return shrink(&m, then: .tuning(hint))
    // раскрытый, HUD и уведомление перетекают прямо в подложку, без схлопывания — как HUD из них же
    case .hover, .expanded, .hud, .alert:
      m.surface = .tuning(hint)
      return [.animate(.hudMorph)]
    case .shrink:
      m.pending = .tuning(hint)
      return []
    case .hoverNudge:
      return []  // разобран выше
    }
  }

  /// Ползунок отпущен: подсказка отслужила, возврат в покой — как у отслужившего уведомления
  /// (hideAlert), без очереди и звука. Если сжатие уже шло к другой цели, подсказку из pending
  /// просто снимаем — освободившееся сжатие вернётся в base само
  private static func tuningReleased(_ m: inout IslandModel) -> [IslandEffect] {
    if case .tuning = m.pending { m.pending = m.base }
    guard case .tuning = m.surface, m.pending == nil else { return [] }
    if m.base != .idle { return shrink(&m, then: m.base) }
    m.surface = .idle
    return [.animate(.tuningOut)]
  }

  /// Вид при раскрытии по Idle Activity. nil — None, раскрывать нечего
  private static func openingView(_ m: IslandModel) -> ExpandedView? {
    m.config.expanded.openingView(last: m.lastExpandedView, hasMedia: m.hasMedia)
  }

  private static func open(_ m: inout IslandModel, to target: Surface, with transition: IslandTransition) -> [IslandEffect] {
    guard m.pending == nil else { return [] }
    let view = target == .expanded ? openingView(m) : nil
    // Idle Activity None: раскрытый не открывается
    if target == .expanded, view == nil { return [] }
    switch m.surface {
    case .idle, .compact, .peek, .calendar, .calendarPeek: break
    case .hover where target == .expanded: break
    case .hoverNudge where target == .expanded:
      // клик во время отклика раскрывает сразу, не дожидаясь таймера. target == .expanded здесь уже
      // гарантирует view != nil (иначе return [] выше) — guard, а не ?? .duo, чтобы не выглядело,
      // будто None открывает Duo
      guard let view else { return [] }
      m.expandedView = view
      m.lastExpandedView = view
      m.surface = target
      return [.cancel(.hoverOpen), .animate(transition)]
    default: return []
    }
    let cancels = peekCancels(from: m.surface)
    if let view {
      m.expandedView = view
      m.lastExpandedView = view
    }
    m.surface = target
    return cancels + [.animate(transition)]
  }

  /// Hover в режиме пользователя: из покоя, компактов и peek раскрытие сразу, а при ненулевой hoverDelay —
  /// сначала отклик и раскрытие по таймеру hoverOpen. Возврат курсора, пока раскрытый ждёт схлопывания, отменяет его
  private static func nudge(_ m: inout IslandModel) -> [IslandEffect] {
    if m.leaving {
      m.leaving = false
      return [.cancel(.hoverLeave)]
    }
    guard m.pending == nil else { return [] }
    switch m.surface {
    case .idle, .compact, .peek, .calendar, .calendarPeek:
      let cancels = peekCancels(from: m.surface)
      let view = openingView(m)
      if m.config.expandsOnHover, m.config.hoverDelay == .zero, let view {
        m.expandedView = view
        m.lastExpandedView = view
        m.surface = .expanded
        return cancels + [.animate(.hoverExpand)]
      }
      m.surface = .hoverNudge(from: m.surface)
      // Expand on hover выключен или Idle Activity None: отклик держится, пока курсор над островом
      guard m.config.expandsOnHover, view != nil else { return cancels + [.animate(.hoverNudge)] }
      return cancels + [
        .animate(.hoverNudge),
        .schedule(.hoverOpen, after: m.config.hoverDelay * m.config.timeScale),
      ]
    default:
      return []
    }
  }

  /// Уход курсора в режиме пользователя: отклик возвращается в покой сразу, раскрытый — после задержки
  private static func leave(_ m: inout IslandModel) -> [IslandEffect] {
    switch m.surface {
    case .hoverNudge(let from):
      m.surface = m.base
      return [.cancel(.hoverOpen), .animate(settle(from: from, to: m.surface))]
    case .hover, .expanded:
      guard !m.leaving else { return [] }
      m.leaving = true
      return [.schedule(.hoverLeave, after: IslandTiming.hoverLeave * m.config.timeScale)]
    default:
      return []
    }
  }

  /// Переход из отклика обратно в покой. Покой мог смениться за время отклика (трек, календарь, полноэкранный)
  private static func settle(from: Surface, to base: Surface) -> IslandTransition {
    switch (from, base) {
    case _ where from == base: .hoverNudgeBack
    case (.peek, .compact): .peekClose
    case (.calendarPeek, .calendar): .calendarPeekClose
    case (_, .compact), (_, .calendar): .compactIn
    default: .compactOut
    }
  }

  private static func close(_ m: inout IslandModel) -> [IslandEffect] {
    guard m.surface == .hover || m.surface == .expanded else { return [] }
    m.surface = m.base
    if m.leaving {
      m.leaving = false
      return [.cancel(.hoverLeave), .animate(.collapse)]
    }
    return [.animate(.collapse)]
  }

  // swiftlint:disable:next cyclomatic_complexity - по case на таймер, разбивка спрячет порядок проверок
  private static func timerFired(_ m: inout IslandModel, _ id: TimerID) -> [IslandEffect] {
    switch id {
    case .peekEnd:
      guard m.surface == .peek else { return [] }
      // за время peek открылось окно календаря: смена активности через сжатие
      if m.base == .calendar { return shrink(&m, then: .calendar) }
      m.surface = m.base
      // peek → покой берёт пружину ухода компакта: это тот же уход живой активности в вырез,
      // и у него есть замер (261 → 186). peekClose — сжатие peek в компакт, его подгонка
      // в задаче 16 по эталону не должна менять уход в вырез
      return [.animate(m.surface == .compact ? .peekClose : .compactOut)]
    case .hudHide:
      guard case .hud = m.surface, m.pending == nil else { return [] }
      if let alert = m.dequeueAlert() { return shrink(&m, then: .alert(alert)) }
      if m.base != .idle { return shrink(&m, then: m.base) }
      m.surface = .idle
      return [.animate(.hudOut)]
    case .grow:
      guard m.surface == .shrink, let target = m.pending else { return [] }
      m.pending = nil
      m.surface = target
      if case .alert(let alert) = target { return [.animate(.alertGrow)] + shown(&m, alert) }
      if case .hud = target {
        return [.animate(.grow), .schedule(.hudHide, after: hudVisible(m, target))]
      }
      return [.animate(.grow)]
    case .hoverOpen:
      // настройку могли выключить, пока таймер уже стоял в очереди: не раскрываем задним числом
      guard m.config.expandsOnHover, case .hoverNudge = m.surface, m.pending == nil, let view = openingView(m) else { return [] }
      m.expandedView = view
      m.lastExpandedView = view
      m.surface = .expanded
      return [.animate(.hoverExpand)]
    case .hoverLeave:
      guard m.leaving else { return [] }
      // таймер уже сработал: отменять нечего
      m.leaving = false
      return close(&m)
    case .alertHide:
      guard case .alert = m.surface, m.pending == nil else { return [] }
      return hideAlert(&m)
    case .calendarPeekEnd:
      guard m.surface == .calendarPeek else { return [] }
      m.surface = .calendar
      return [.animate(.calendarPeekClose)]
    case .mediaIdle:
      guard m.hasMedia, !m.isPlaying, !m.mediaIdle else { return [] }
      let old = m.base
      m.mediaIdle = true
      return baseChanged(&m, from: old)
    }
  }

  /// Уход показанного уведомления: к следующему из очереди, иначе в покой
  private static func hideAlert(_ m: inout IslandModel) -> [IslandEffect] {
    if let next = m.dequeueAlert() { return shrink(&m, then: .alert(next)) }
    if m.base != .idle { return shrink(&m, then: m.base) }
    m.surface = .idle
    return [.animate(.alertOut)]
  }

  /// Смена активности: сжатие почти до выреза, раскрытие в target по таймеру grow
  private static func shrink(_ m: inout IslandModel, then target: Surface) -> [IslandEffect] {
    let transition = shrinkTransition(from: m.surface)
    let cancels = peekCancels(from: m.surface)
    m.surface = .shrink
    m.pending = target
    return cancels + [.animate(transition), .schedule(.grow, after: IslandTiming.shrink * m.config.timeScale)]
  }

  /// Остров уходит из peek: таймер peek музыки снимается всегда (как было), таймер peek календаря — при
  /// уходе из него, иначе он сработает позже впустую или, после нового старта события, оборвёт новый peek
  private static func peekCancels(from source: Surface) -> [IslandEffect] {
    source == .calendarPeek ? [.cancel(.peekEnd), .cancel(.calendarPeekEnd)] : [.cancel(.peekEnd)]
  }

  /// Пружина сжатия выбирается по исходному состоянию: у Alcove сжатие из компакта (261 → ~195)
  /// пружинит (345/30.5, ζ 0.82), а из широкого HUD (369 → ~199) идёт без отскока (360/38).
  /// Каждый новый широкий источник (alert, календарь) добавляет сюда свой case со своим замером
  /// (пример — .alert → .alertShrink), а не попадает молча в пружину компакта: switch без default
  private static func shrinkTransition(from source: Surface) -> IslandTransition {
    switch source {
    case .hud: .shrinkFromWide
    // замер записи №2 (capture/analysis/README.md): Charging → сжатие 335/37. Замера нет для сжатия
    // из напоминания календаря (высота 73.5) и AirPods, взят замер Charging
    case .alert: .alertShrink
    // hoverNudge разворачивается в исходный компакт или peek до сжатия (hudChanged, alertArrived)
    case .compact, .peek, .hoverNudge: .shrink
    // замера нет: компакт календаря той же высоты 32, что компакт музыки, peek — как peek музыки
    case .calendar, .calendarPeek: .shrink
    // Task 17t: замера нет, подложка близка по масштабу к компакту (не к широкому HUD) — та же пружина
    case .tuning: .shrink
    // отсюда сжатия нет: покой показывает HUD сразу, раскрытый морфится, сжатие уже идёт
    case .idle, .hover, .expanded, .shrink: .shrink
    }
  }
}

/// Сколько HUD держится после последнего изменения, по виду
public struct HUDDurations: Equatable, Sendable {
  public var volume: Duration = IslandTiming.hudVisible
  public var brightness: Duration = IslandTiming.hudVisible

  public init() {}

  public func duration(for kind: HUDKind) -> Duration {
    kind == .volume ? volume : brightness
  }
}  // swiftlint:disable:this file_length - редьюсер машины, разбивка вне задачи
