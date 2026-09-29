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
    /// General → Gestures → Swipe to dismiss activity
    @ObservationIgnored var swipeToDismiss = true
    /// Свайп по покою: свой трекер, у раскрытого — tracker
    @ObservationIgnored private var restTracker = SwipeTracker()
    /// Кто ведёт текущий жест: решается один раз на .began по surface на тот момент и держится
    /// до .ended/.cancelled. Без этого surface, сменившийся посреди жеста (например, close раскрытого
    /// увёл его в компакт), увёл бы остаток тех же пальцев ко второму трекеру и выполнил бы второе
    /// действие тем же движением (review Task 15)
    private enum SwipeOwner { case none, expanded, rest }
    @ObservationIgnored private var swipeOwner = SwipeOwner.none
    /// Отладочная повестка держится, пока источник календаря шлёт реальные события: pinDebugEvents/unpinDebugEvents
    private(set) var isDebugAgendaPinned = false
    /// Последние реальные события с живого источника: из них соберётся agenda после unpinDebugEvents
    @ObservationIgnored private var lastRealEvents: [CalendarEvent] = []
    /// Вырез этой машины по API до первой расстановки окна (лог window 28.09)
    var notch = CGSize(width: 185, height: 32)
    /// Вид страниц настроек, которые не меняют поведение машины: Battery и т.д. (IslandAppearance)
    var appearance = IslandAppearance.default
    /// Уровень текущего выхода 0…1: строка громкости плеера читает его, AppDelegate обновляет
    var volumeLevel: Double = 0

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

    /// Режим машины. Demo-прогон переключает на .alcove: эталон сверки записан с поведением Alcove.
    /// Настройки могут сменить покой (Now Playing выключен): машина переводит остров сама
    var config: IslandMachine.Config {
        get { model.config }
        set {
            let old = model.base
            model.config = newValue
            if model.base != old { send(.baseChanged(from: old)) }
        }
    }

    var spec: IslandShapeSpec {
        var spec = IslandGeometry.spec(
            for: model.surface, hasMedia: model.hasMedia, notch: notch,
            calendarIndicatorWidth: IslandView.calendarIndicatorWidth,
            reminderIndicatorWidth: IslandView.reminderIndicatorWidth, battery: appearance.battery,
            calendarWithMusic: model.showsMedia, volumeRow: model.volumeRowShown)
        if model.surface == .expanded, stretch != 0 {
            spec.size.height += stretch
            // IslandGeometry.spec тоже держит радиус по высоте без строки громкости (комментарий у bottomRadius):
            // без вычитания радиус на старте свайпа скакнул бы с 35 (175) на ~40.5 (207+stretch)
            let radiusHeight = spec.size.height - (model.volumeRowShown ? IslandGeometry.volumeRowHeight : 0)
            spec.bottomRadius = IslandGeometry.bottomRadius(forHeight: radiusHeight)
        }
        return spec
    }

    /// Окно календаря открылось (событие) или закрылось (nil). Зовёт CalendarClock и отладка
    func setCalendarLive(_ event: CalendarEvent?) {
        if let event { calendarEvent = event }
        send(.calendarLiveChanged(event != nil))
    }

    /// Покой, по которому свайп убирает и возвращает активность
    nonisolated static func isRestSwipeSurface(_ surface: Surface) -> Bool {
        switch surface {
        case .idle, .compact, .peek, .calendar, .calendarPeek, .hoverNudge: true
        default: false
        }
    }

    /// Свайп трекпада: раскрытый листает/закрывается, покой убирает/возвращает активность. Кто ведёт жест,
    /// решается на .began и не меняется до конца жеста (swipeOwner) — surface может смениться посреди
    /// жеста (close раскрытого уводит его в компакт), но остаток тех же пальцев не должен достаться
    /// другому трекеру и выполнить второе действие
    func swipe(_ phase: SwipeTracker.Phase, dx: CGFloat = 0, dy: CGFloat) {
        if phase == .began {
            tracker = SwipeTracker()
            restTracker = SwipeTracker()
            swipeOwner = model.surface == .expanded ? .expanded
                : (swipeToDismiss && Self.isRestSwipeSurface(model.surface) ? .rest : .none)
        }
        switch swipeOwner {
        case .expanded: swipeExpanded(phase, dx: dx, dy: dy)
        case .rest: restSwipe(phase, dx: dx, dy: dy)
        case .none:
            stretch = 0
            dragBlurred = false
        }
        if phase == .ended || phase == .cancelled { swipeOwner = .none }
    }

    /// Двухпальцевый свайп над раскрытым (ui-inspection 3.7). Тяга идёт за пальцами без анимации.
    /// Блюр анимируется здесь, через withAnimation, а не .animation во вью: так он не перебивает
    /// пружину перехода машины (HUD или уведомление посреди жеста), а едет в её транзакции
    private func swipeExpanded(_ phase: SwipeTracker.Phase, dx: CGFloat, dy: CGFloat) {
        // surface могла уйти из .expanded не через сам жест (HUD, уведомление, полноэкранный —
        // owner заперт на .expanded до .ended/.cancelled и продолжает сюда попадать): тяга и блюр
        // не должны зависнуть ненулевыми и исказить высоту следующего раскрытия (review Task 15)
        guard model.surface == .expanded else {
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

    /// Свайп по компакту и форме выреза: пороги те же 21 pt, форма за пальцами не тянется (замера у Alcove нет).
    /// Отклик и onSwipeClose — только когда dismissed реально сменился: иначе свайп без активности
    /// (покой пуст, уже убрано, свайп вниз, когда нечего возвращать) держал бы остров закрытым под курсором
    /// без причины и блокировал бы досылку hoverEntered после следующего alert/HUD (review Task 15)
    private func restSwipe(_ phase: SwipeTracker.Phase, dx: CGFloat, dy: CGFloat) {
        guard let output = restTracker.feed(phase, dx: dx, dy: dy) else { return }
        switch output {
        case .close:
            // send зовёт onSurfaceChange синхронно, а тот в окне — surfaceChanged(), который может
            // тут же (тем же кадром) послать hoverEntered обратно, пока курсор ещё над вырезом:
            // onSwipeClose должен успеть выставить closedBySwipe ДО send, иначе она приходит поздно
            // и свайп сам себя отменяет (review Task 15). Пробуем реакцию машины на копии модели, не трогая
            // реальную и не вызывая колбэков, чтобы решить, было ли что убирать, раньше настоящего send
            var probe = model
            _ = IslandMachine.reduce(&probe, .activityDismissed)
            guard probe.dismissed != model.dismissed else { return }
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            onSwipeClose()
            send(.activityDismissed)
        case .cycle:
            let wasDismissed = model.dismissed
            send(.activityRestored)
            guard model.dismissed != wasDismissed else { return }
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case .stretch, .settle:
            break
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
            send(info.isPlaying ? .trackChanged : .pausedTrackChanged)
        case let .updated(info):
            nowPlaying = info
            if info.isPlaying != model.isPlaying { send(.playbackChanged(info.isPlaying)) }
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
