import AppKit
import IslandCore
import IslandSources
import IslandUI
import Observation
import SwiftUI

/// Держит модель острова и исполняет эффекты машины: анимации через withAnimation, таймеры через Task
@MainActor
@Observable
final class IslandStore {
    private(set) var model: IslandModel
    private(set) var nowPlaying: NowPlayingInfo?
    /// События сегодня и завтра: Duo и календарь
    private(set) var agenda = DayAgenda.empty
    /// Событие окна календаря: его рисуют компакт и peek. Остаётся после конца окна, пока компакт уходит
    private(set) var calendarEvent: CalendarEvent?
    /// Тяга свайпа: добавка к высоте раскрытого, вниз +, вверх −
    private(set) var stretch: CGFloat = 0
    /// Остров тянут вверх: контент в блюре
    private(set) var dragBlurred = false
    @ObservationIgnored private var tracker = SwipeTracker()
    /// Отладочная повестка держится, пока источник календаря шлёт реальные события: pinDebugEvents/unpinDebugEvents
    private(set) var isDebugAgendaPinned = false
    /// Последние реальные события с живого источника: из них соберётся agenda после unpinDebugEvents
    @ObservationIgnored private var lastRealEvents: [CalendarEvent] = []
    /// Вырез этой машины по API до первой расстановки окна (лог window 28.09)
    var notch = CGSize(width: 185, height: 32)

    @ObservationIgnored var onAction: (PlayerAction) -> Void = { _ in }
    /// Звук уведомления: AppDelegate подключает сюда SoundPlayer.play, если в настройках включён Play sounds
    @ObservationIgnored var onSound: (IslandSound) -> Void = { _ in }
    /// Кнопка Join на карточке события: AppDelegate открывает ссылку
    @ObservationIgnored var onJoin: (URL) -> Void = { _ in }
    /// Вызывается после смены surface: окно пересчитывает hit-testing, даже если мышь стоит на месте
    @ObservationIgnored var onSurfaceChange: () -> Void = {}
    /// Остров закрыт свайпом вверх: окно не досылает hoverEntered, пока курсор не уйдёт с острова
    @ObservationIgnored var onSwipeClose: () -> Void = {}
    /// Повестка сменилась (живой источник, отладочная повестка, возврат к реальной): AppDelegate кормит ею CalendarClock
    @ObservationIgnored var onAgendaChange: (DayAgenda) -> Void = { _ in }
    @ObservationIgnored private var timers: [TimerID: Task<Void, Never>] = [:]

    init(config: IslandMachine.Config = .user) {
        model = IslandModel(config: config)
    }

    /// Режим машины. Demo-прогон переключает на .alcove: эталон сверки записан с поведением Alcove
    var config: IslandMachine.Config {
        get { model.config }
        set { model.config = newValue }
    }

    var spec: IslandShapeSpec {
        var spec = IslandGeometry.spec(
            for: model.surface, hasMedia: model.hasMedia, notch: notch,
            calendarIndicatorWidth: IslandView.calendarIndicatorWidth,
            reminderIndicatorWidth: IslandView.reminderIndicatorWidth)
        if model.surface == .expanded, stretch != 0 {
            spec.size.height += stretch
            spec.bottomRadius = IslandGeometry.bottomRadius(forHeight: spec.size.height)
        }
        return spec
    }

    /// Окно календаря открылось (событие) или закрылось (nil). Зовёт CalendarClock и отладка
    func setCalendarLive(_ event: CalendarEvent?) {
        if let event { calendarEvent = event }
        send(.calendarLiveChanged(event != nil))
    }

    /// Двухпальцевый свайп над раскрытым (ui-inspection 3.7). Тяга идёт за пальцами без анимации.
    /// Блюр анимируется здесь, через withAnimation, а не .animation во вью: так он не перебивает
    /// пружину перехода машины (HUD или уведомление посреди жеста), а едет в её транзакции
    func swipe(_ phase: SwipeTracker.Phase, dx: CGFloat = 0, dy: CGFloat) {
        guard model.surface == .expanded else {
            tracker = SwipeTracker()
            stretch = 0
            dragBlurred = false
            return
        }
        guard let output = tracker.feed(phase, dx: dx, dy: dy) else { return }
        let timeScale = model.config.timeScale
        switch output {
        case let .stretch(value):
            stretch = value
            let blurred = value < 0
            if blurred != dragBlurred {
                // контент уходит в блюр за ~0.1 с (ui-inspection 3.7), замедляется timeScale
                withAnimation(.easeOut(duration: 0.1 * timeScale)) { dragBlurred = blurred }
            }
        case .close:
            // тягу и блюр сбрасывает send: остров уходит из раскрытого, и они едут той же пружиной схлопывания.
            // Отдача трекпада на закрытии: пользователь чувствует её у Alcove (ui-inspection 3.7).
            // Момент у Alcove не замерен: даём на пересечении порога, вместе со схлопыванием
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            onSwipeClose()
            // закрытие свайпом — то же схлопывание, что клик мимо острова
            send(.clickedOutside)
        case .cycle:
            // высота возвращается к 175 за ~0.2 с одновременно со сменой вида (ui-inspection 3.7).
            // Замедляется timeScale, как остальные анимации острова. Порог пройден посреди жеста, как у закрытия,
            // и отдача та же (решение 28.09): пользователь чувствует, что вид сменился, не отпуская пальцев
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            withAnimation(.smooth(duration: 0.2 * timeScale)) { stretch = 0 }
            send(.expandedViewCycled)
        case .settle:
            // не дотянул: пружина обратно к 175 за ~0.4 с (ui-inspection 3.7)
            withAnimation(.smooth(duration: 0.4 * timeScale)) {
                stretch = 0
                dragBlurred = false
            }
        }
    }

    func send(_ event: IslandEvent) {
        var next = model
        let previous = model.surface
        let effects = IslandMachine.reduce(&next, event)

        var transition: IslandTransition?
        for case let .animate(t) in effects { transition = t }
        // ушли из раскрытого посреди свайпа (уход курсора, уведомление, HUD): тяга и блюр не должны
        // пережить схлопывание и достаться следующему раскрытию. Сбрасываются той же пружиной, что и форма
        let apply = {
            self.model = next
            if next.surface != .expanded {
                self.stretch = 0
                self.dragBlurred = false
            }
        }
        if let spring = transition.flatMap({ IslandMotion.spring(for: $0, timeScale: next.config.timeScale) }) {
            withAnimation(spring.animation, apply)
        } else {
            apply()
        }
        if transition?.opensByHover == true {
            // .generic, а не .levelChange: levelChange — щелчок шага значения (слайдер, громкость),
            // а раскрытие острова — обычное подтверждение действия. Трекпад отдаёт отклик,
            // только если на нём лежит палец, от мыши его нет
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }

        for effect in effects {
            switch effect {
            case .animate:
                break
            case let .schedule(id, delay):
                timers[id]?.cancel()
                timers[id] = Task { [weak self] in
                    try? await Task.sleep(for: delay)
                    guard !Task.isCancelled else { return }
                    self?.timers[id] = nil
                    self?.send(.timerFired(id))
                }
            case let .cancel(id):
                timers[id]?.cancel()
                timers[id] = nil
            case let .play(sound):
                onSound(sound)
            }
        }
        // после эффектов: вложенный send из колбэка не перемешается с таймерами этого события
        if model.surface != previous { onSurfaceChange() }
    }

    func apply(_ change: NowPlayingChange) {
        switch change {
        case let .newTrack(info):
            nowPlaying = info
            send(.trackChanged)
        case let .updated(info):
            nowPlaying = info
        case .cleared:
            nowPlaying = nil
            send(.mediaCleared)
        }
    }

    /// События с живого источника календаря. Agenda считается от текущего времени, но пока держится
    /// отладочная повестка (calendar.duo-event/calendar.duo-empty), сюда не пишем: реальные события
    /// запоминаются и лягут в agenda по unpinDebugEvents
    func apply(events: [CalendarEvent], now: Date = Date()) {
        lastRealEvents = events
        guard !isDebugAgendaPinned else { return }
        agenda = DayAgenda.make(events: events, now: now)
        onAgendaChange(agenda)
    }

    /// Отладочная повестка вместо реальной: держится до unpinDebugEvents, реальные события не пропадают,
    /// просто не показываются, пока источник продолжает слать apply(events:)
    func pinDebugEvents(_ events: [CalendarEvent], now: Date = Date()) {
        isDebugAgendaPinned = true
        agenda = DayAgenda.make(events: events, now: now)
        onAgendaChange(agenda)
    }

    /// Возврат к реальному календарю: agenda пересобирается из последних событий живого источника
    func unpinDebugEvents(now: Date = Date()) {
        isDebugAgendaPinned = false
        agenda = DayAgenda.make(events: lastRealEvents, now: now)
        onAgendaChange(agenda)
    }
}
