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
}

public enum IslandEvent: Equatable, Sendable {
    case trackChanged
    case mediaCleared
    case hudChanged(HUDKind, level: Double)
    case alertArrived(IslandAlert)
    /// Уведомление этого вида больше не нужно (Dismiss Event): ждущие в очереди уходят. Показанное уходит сразу,
    /// как по alertHide, а сжатие к нему идёт к следующему из очереди или в покой
    case alertRetracted(IslandAlert.Kind)
    /// Открылось или закрылось окно календаря: от минуты до начала события до его конца
    case calendarLiveChanged(Bool)
    /// Событие началось: peek с названием поверх компакта календаря и звук
    case calendarStarted
    /// Свайп вниз по раскрытому: следующий вид
    case expandedViewCycled
    case hoverEntered, hoverExited
    case clicked, clickedOutside
    /// На экране с вырезом открылось или закрылось полноэкранное приложение
    case fullscreenChanged(Bool)
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
    /// Открыто окно календаря (T−1 мин … конец события): компакт календаря вытесняет музыку (решение 27.09)
    public var calendarLive = false
    /// Вид раскрытого. Каждое раскрытие начинается с Duo (ui-inspection 3.7, «Переоткрытие сбрасывает вид на Duo»)
    public var expandedView: ExpandedView = .duo

    public init(config: IslandMachine.Config = .user) {
        self.config = config
    }

    /// Состояние покоя. Календарь важнее музыки. В полноэкранном и без compactAtRest — форма выреза
    public var base: Surface {
        guard config.compactAtRest, !isFullscreen else { return .idle }
        if calendarLive { return .calendar }
        return hasMedia ? .compact : .idle
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
public enum IslandMachine {
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
        switch event {
        case .trackChanged: trackChanged(&model)
        case .mediaCleared: mediaCleared(&model)
        case let .hudChanged(kind, level): hudChanged(&model, .hud(kind, level: level))
        case let .alertArrived(alert): alertArrived(&model, alert)
        case let .alertRetracted(kind): alertRetracted(&model, kind)
        case let .calendarLiveChanged(live): calendarLiveChanged(&model, live)
        case .calendarStarted: calendarStarted(&model)
        case .expandedViewCycled: expandedViewCycled(&model)
        case .hoverEntered:
            model.config.hoverOpensPlayer ? nudge(&model) : open(&model, to: .hover, with: .hoverOpen)
        case .clicked: open(&model, to: .expanded, with: .expand)
        case .hoverExited: model.config.hoverOpensPlayer ? leave(&model) : close(&model)
        case .clickedOutside: close(&model)
        case let .fullscreenChanged(on): fullscreenChanged(&model, on)
        case let .timerFired(id): timerFired(&model, id)
        }
    }

    /// Покой: форма выреза, компакт музыки или календаря. После сжатия к покою цель пересчитывается по base
    private static func isRest(_ surface: Surface) -> Bool {
        surface == .idle || surface == .compact || surface == .calendar
    }

    private static func trackChanged(_ m: inout IslandModel) -> [IslandEffect] {
        m.hasMedia = true
        // после сжатия остров вернётся в покой, а покой зависит от музыки
        if let pending = m.pending, isRest(pending) { m.pending = m.base }
        switch m.surface {
        case .idle where m.isFullscreen:
            // в полноэкранном музыка только запоминается: компакт появится после выхода
            return []
        case .idle where m.pending == nil && m.config.compactAtRest:
            m.surface = .compact
            return [.animate(.compactIn)]
        case .idle where m.pending == nil:
            // без компакта в покое смена трека коротко показывает peek и уходит обратно в форму выреза
            m.surface = .peek
            return [.animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek)]
        case .compact where m.pending == nil:
            m.surface = .peek
            return [.animate(.peekOpen), .schedule(.peekEnd, after: IslandTiming.quickPeek)]
        default:
            // peek не перезапускаем. При компакте календаря и в остальных состояниях меняется только контент
            return []
        }
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
        if let pending = m.pending, isRest(pending) { m.pending = m.base }
        switch m.surface {
        case .compact, .peek:
            m.surface = .idle
            return [.cancel(.peekEnd), .animate(.compactOut)]
        default:
            return []
        }
    }

    private static func hudChanged(_ m: inout IslandModel, _ hud: Surface) -> [IslandEffect] {
        if case let .hoverNudge(from) = m.surface {
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
            if case let .alert(alert) = m.pending { m.displaceByHUD(alert, heard: false) }
            m.pending = hud
            return []
        }
        switch m.surface {
        case .hud:
            m.surface = hud
            return [.animate(.hudUpdate), .schedule(.hudHide, after: IslandTiming.hudVisible)]
        case .idle:
            m.surface = hud
            return [.animate(.hudIn), .schedule(.hudHide, after: IslandTiming.hudVisible)]
        // HUD важнее уведомления: уведомление уходит через сжатие, важное вернётся после HUD (displaceByHUD)
        case let .alert(alert):
            m.displaceByHUD(alert, heard: true)
            return shrink(&m, then: hud)
        case .compact, .peek, .calendar, .calendarPeek:
            return shrink(&m, then: hud)
        case .hover, .expanded:
            // раскрытый морфится прямо в HUD, без схлопывания и сжатия (осмотр нативного Alcove 26.09).
            // После HUD раскрытый не возвращается: hudHide уводит в покой
            m.surface = hud
            return [.animate(.hudMorph), .schedule(.hudHide, after: IslandTiming.hudVisible)]
        case .shrink:
            m.pending = hud
            return []
        case .hoverNudge:
            return []
        }
    }

    /// Уведомление: из покоя сразу, из компакта через сжатие, из раскрытого морфом, как HUD (решение 27.09).
    /// Во время HUD и уведомления другого вида ждёт в очереди. Тот же вид обновляет показанное и продлевает его
    private static func alertArrived(_ m: inout IslandModel, _ alert: IslandAlert) -> [IslandEffect] {
        // новое уведомление вида, вытесненного HUD, — новый показ со звуком
        m.heardAlerts.remove(alert.kind)
        if case let .hoverNudge(from) = m.surface {
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
            case let .alert(next) where next.kind != alert.kind:
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
        case let .alert(current) where current.kind == alert.kind:
            m.surface = .alert(alert)
            return [.animate(.alertUpdate), .schedule(.alertHide, after: m.config.alerts.duration(for: alert))]
        case .alert, .hud:
            m.enqueue(alert)
            return []
        case .compact, .peek, .calendar, .calendarPeek:
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
        if case let .alert(pending) = m.pending, pending.kind == kind {
            m.pending = m.dequeueAlert().map(Surface.alert) ?? m.base
        }
        // показанное уходит сразу: иначе его вытеснил бы HUD и вернул в очередь (displaceByHUD)
        if case let .alert(shown) = m.surface, shown.kind == kind, m.pending == nil {
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
        m.calendarLive = live
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
    /// Во время HUD, сжатия и раскрытого — только звук. Вживую окно открывается за 60 с до старта, и сжатие
    /// к календарю к этому времени давно закончилось: сюда попадает разве что отладочная кнопка calendar.start
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
        return [.animate(.viewSwap)]
    }

    private static func open(_ m: inout IslandModel, to target: Surface, with transition: IslandTransition) -> [IslandEffect] {
        guard m.pending == nil else { return [] }
        switch m.surface {
        case .idle, .compact, .peek, .calendar, .calendarPeek: break
        case .hover where target == .expanded: break
        case .hoverNudge where target == .expanded:
            // клик во время отклика раскрывает сразу, не дожидаясь таймера
            m.expandedView = .duo
            m.surface = target
            return [.cancel(.hoverOpen), .animate(transition)]
        default: return []
        }
        let cancels = peekCancels(from: m.surface)
        if target == .expanded { m.expandedView = .duo }
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
            if m.config.expandsOnHover, m.config.hoverDelay == .zero {
                m.expandedView = .duo
                m.surface = .expanded
                return cancels + [.animate(.hoverExpand)]
            }
            m.surface = .hoverNudge(from: m.surface)
            // Expand on hover выключен: отклик держится, пока курсор над островом, раскрывает клик
            guard m.config.expandsOnHover else { return cancels + [.animate(.hoverNudge)] }
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
        case let .hoverNudge(from):
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
            if case let .alert(alert) = target { return [.animate(.alertGrow)] + shown(&m, alert) }
            if case .hud = target {
                return [.animate(.grow), .schedule(.hudHide, after: IslandTiming.hudVisible)]
            }
            return [.animate(.grow)]
        case .hoverOpen:
            // настройку могли выключить, пока таймер уже стоял в очереди: не раскрываем задним числом
            guard m.config.expandsOnHover, case .hoverNudge = m.surface, m.pending == nil else { return [] }
            m.expandedView = .duo
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
        // отсюда сжатия нет: покой показывает HUD сразу, раскрытый морфится, сжатие уже идёт
        case .idle, .hover, .expanded, .shrink: .shrink
        }
    }
}
