import IslandCore
import SwiftUI

/// Остров целиком: форма и контент по состоянию. Размер окна фиксированный, анимируется только форма
public struct IslandView: View {
  let model: IslandModel
  let spec: IslandShapeSpec
  let notchWidth: CGFloat
  let nowPlaying: NowPlayingInfo?
  let agenda: DayAgenda
  let claude: ClaudePanel?
  let soon: SoonPanel?
  let onSoonAction: (SoonAction) -> Void
  /// Отклонённые через Dismiss Event: стопка Duo их не показывает
  let dismissedEvents: Set<String>
  let calendarEvent: CalendarEvent?
  /// Остров тянут свайпом вверх: контент в блюре
  let dragBlurred: Bool
  let appearance: IslandAppearance
  /// Фон под раскрытым тёмный: Contrast outline виден только над ним. Без замера — тёмный
  let backdropDark: Bool
  /// Уровень строки громкости плеера 0…1
  let volume: Double
  let onClick: () -> Void
  let onAction: (PlayerAction) -> Void
  let onJoin: (URL) -> Void

  public init(
    model: IslandModel, spec: IslandShapeSpec, notchWidth: CGFloat, nowPlaying: NowPlayingInfo?,
    agenda: DayAgenda = .empty,
    claude: ClaudePanel? = nil,
    soon: SoonPanel? = nil,
    dismissedEvents: Set<String> = [],
    calendarEvent: CalendarEvent? = nil,
    dragBlurred: Bool = false,
    appearance: IslandAppearance = .default,
    backdropDark: Bool = true,
    volume: Double = 0,
    onClick: @escaping () -> Void, onAction: @escaping (PlayerAction) -> Void,
    onJoin: @escaping (URL) -> Void = { _ in },
    onSoonAction: @escaping (SoonAction) -> Void = { _ in }
  ) {
    self.model = model
    self.spec = spec
    self.notchWidth = notchWidth
    self.nowPlaying = nowPlaying
    self.agenda = agenda
    self.claude = claude
    self.soon = soon
    self.onSoonAction = onSoonAction
    self.dismissedEvents = dismissedEvents
    self.calendarEvent = calendarEvent
    self.dragBlurred = dragBlurred
    self.appearance = appearance
    self.backdropDark = backdropDark
    self.volume = volume
    self.onClick = onClick
    self.onAction = onAction
    self.onJoin = onJoin
  }

  public var body: some View {
    ZStack(alignment: .top) {
      // Progressive blur — под тенью и формой. Вид живёт только у раскрытого: иначе WindowServer снимал бы фон
      // под окном и в покое. Появляется и уходит той же анимацией, что тень (withAnimation модели)
      if Self.showsBlur(surface: model.surface, enabled: appearance.progressiveBlur) {
        GeometryReader { proxy in
          VariableBlurView(shape: Self.blurShape(spec, width: proxy.size.width))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
      }
      IslandShape(spec: spec)
        // подложка подгонки выреза красная, а не чёрная, как обычно (Task 17t, Alcove 1.7.9, 29.09)
        .fill(isTuningHint ? IslandPalette.tuning : IslandPalette.background)
        // тень только у раскрытого: меняется вместе с моделью внутри withAnimation и растёт той же пружиной
        .shadow(
          color: .black.opacity(model.surface == .expanded ? IslandGeometry.Shadow.opacity : 0),
          radius: IslandGeometry.Shadow.radius,
          y: IslandGeometry.Shadow.y)
      // поверх тени, под контентом: проявляется и гаснет вместе с тенью, форма анимируется той же пружиной.
      // Смена фона под островом приходит без withAnimation — свой короткий переход только по ней
      ContrastOutline(spec: spec)
        .opacity(
          ContrastOutline.isVisible(surface: model.surface, enabled: appearance.contrastOutline, backdropDark: backdropDark) ? 1 : 0
        )
        .animation(.easeInOut(duration: 0.2), value: backdropDark)
      content
        .modifier(OpenScale(size: spec.size, target: spec.size, scalesContent: model.surface == .expanded))
        .clipShape(IslandShape(spec: spec, shoulder: 0))
        // тянут вверх: контент уходит в блюр и темнеет с первого движения (ui-inspection 3.7). Сила — оценка.
        // Анимацию задаёт store (withAnimation), своей здесь нет: иначе она перебивала бы пружины переходов
        .blur(radius: dragBlurred ? 8 : 0)
        .opacity(dragBlurred ? 0.6 : 1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .contentShape(IslandShape(spec: spec))
    .onTapGesture(perform: islandClicked)
  }

  @ViewBuilder
  private var content: some View {
    switch model.surface {
    // отклик на hover в той же ветке: вью музыки не пересоздаётся и не играет переход
    case .compact, .peek, .hoverNudge(from: .compact), .hoverNudge(from: .peek):
      MusicLiveView(info: nowPlaying, notchWidth: notchWidth, showsTitle: liveSurface == .peek, appearance: appearance)
        // рамка итогового размера, а не текущей формы: обложка и волна стоят на своих местах
        // и открываются маской формы, а не едут вместе с её краями. Уходящий вью держит свою рамку.
        // В отклике рамка исходного состояния: форма расширяется вокруг контента, он не сдвигается
        .frame(width: liveSize.width, height: liveSize.height, alignment: .top)
        .id(ContentID.music)
        .transition(.slot)
    case .calendar, .calendarPeek, .hoverNudge(from: .calendar), .hoverNudge(from: .calendarPeek):
      CalendarLiveView(
        event: calendarEvent, music: model.showsMedia ? nowPlaying : nil,
        showsLine: liveSurface == .calendarPeek, notchWidth: notchWidth, appearance: appearance
      )
      // как у музыки: рамка итогового размера, контент открывается маской формы
      .frame(width: liveSize.width, height: liveSize.height, alignment: .top)
      .id(ContentID.calendar)
      .transition(.slot)
    case .expanded:
      // раскрытый открывается в Duo, как в Alcove (решение 27.09). Плеер и календарь — листанием (ui-inspection 3.7)
      // calendarEvent store хранит и после закрытия окна: в Duo оно идёт, только пока окно открыто
      ExpandedContent(
        view: model.expandedView, info: nowPlaying, agenda: agenda, claude: claude,
        soon: soon, onSoonAction: onSoonAction, dismissedEvents: dismissedEvents,
        appearance: appearance,
        liveEvent: model.calendarLive ? calendarEvent : nil, volume: volume,
        showsVolumeRow: model.volumeRowShown, onAction: onAction, onJoin: onJoin,
        timeScale: model.config.timeScale
      )
      .id(ContentID.expanded)
      .transition(.playerEntrance(timeScale: model.config.timeScale))
    case .hud(let kind, let level):
      HUDView(kind: kind, level: level, notchWidth: notchWidth, appearance: appearance.hud(kind), deviceSymbol: appearance.output.symbol)
        // как у музыки: в узкой рамке растущей формы подпись переносилась на две строки
        .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
        .id(ContentID.hud(kind))
        .transition(.slot)
    case .alert(let alert):
      AlertView(alert: alert, notchWidth: notchWidth, battery: appearance.battery)
        // как у HUD: рамка текущей формы, контент разъезжается вместе с краями
        .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
        .id(ContentID.alert)
        .transition(.slot)
    case .tuning(let hint):
      TuningHintView(hint: hint, notchWidth: notchWidth)
        .frame(width: spec.size.width, height: spec.size.height, alignment: .top)
        .id(ContentID.tuning)
        .transition(.slot)
    case .idle, .hover, .shrink, .hoverNudge:
      Color.clear
    }
  }

  private func islandClicked() {
    if model.surface == .expanded, model.expandedView == .soon { return }
    if case .alert(.soon(let notice)) = model.surface {
      guard notice.reminderIDs.count == 1,
        let reminder = soon?.reminders.first(where: { $0.occurrenceID == notice.occurrenceID })
      else {
        onSoonAction(.showList)
        return
      }
      onSoonAction(.open(id: reminder.id, revision: reminder.revision))
      return
    }
    onClick()
  }

  static func showsBlur(surface: Surface, enabled: Bool) -> Bool {
    enabled && surface == .expanded
  }

  /// Форма с ушками в координатах окна: по центру, верх у края экрана (как IslandShape)
  static func blurShape(_ spec: IslandShapeSpec, width: CGFloat) -> CGRect {
    let shapeWidth = spec.size.width + 2 * spec.shoulder
    return CGRect(x: (width - shapeWidth) / 2, y: 0, width: shapeWidth, height: spec.size.height)
  }

  /// Подложка подгонки выреза (Task 17t) — заливка формы красная, а не обычная чёрная
  private var isTuningHint: Bool {
    if case .tuning = model.surface { return true }
    return false
  }

  /// Ширина самого широкого индикатора компакта календаря: по ней считается фиксированная ширина
  /// компакта и peek (IslandGeometry.calendarSize). Store берёт её же, чтобы форма и рамка контента совпали
  public nonisolated static let calendarIndicatorWidth =
    ActivityCompactView.indicatorWidth(ActivityLayouts.calendarWidestIndicator)

  /// Ширина «15m», самого широкого индикатора напоминания: пол ширины напоминания
  /// (IslandGeometry.size(for:notch:reminderIndicatorWidth:)). Store берёт её же, как calendarIndicatorWidth
  public nonisolated static let reminderIndicatorWidth =
    ActivityCompactView.indicatorWidth(ActivityLayouts.reminderWidestIndicator)

  /// Состояние, по которому раскладывается живая активность (музыка, календарь): для отклика — то,
  /// из которого он открылся
  private var liveSurface: Surface {
    if case .hoverNudge(let from) = model.surface { return from }
    return model.surface
  }

  private var liveSize: CGSize {
    let notch = CGSize(width: notchWidth, height: spec.size.height)
    return IslandGeometry.spec(
      for: liveSurface, hasMedia: model.hasMedia, notch: notch, calendarIndicatorWidth: Self.calendarIndicatorWidth,
      reminderIndicatorWidth: Self.reminderIndicatorWidth, calendarWithMusic: model.showsMedia
    ).size
  }

  private enum ContentID: Hashable {
    case music, expanded
    case calendar
    case hud(HUDKind)
    case alert
    case tuning
  }
}
