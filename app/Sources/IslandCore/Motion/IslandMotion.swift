/// Переходы острова: у каждого своя пружина
public enum IslandTransition: Equatable, Sendable {
  case compactIn, compactOut
  case peekOpen, peekClose
  /// hoverOpen — hover в мини-состояние (режим Alcove), hoverExpand — hover сразу в полный плеер
  case hoverOpen, hoverExpand, expand, collapse
  /// Отклик на hover перед раскрытием (режим пользователя) и возврат из него, если курсор ушёл раньше
  case hoverNudge, hoverNudgeBack
  case hudIn, hudOut, hudUpdate
  /// Раскрытый остров перетекает прямо в HUD
  case hudMorph
  /// Сжатие почти до выреза перед сменой активности и раскрытие в новую.
  /// shrinkFromWide — то же сжатие из широкого состояния (HUD) обратно к компакту: у Alcove у него своя пружина
  case shrink, shrinkFromWide, grow

  /// Уведомление: вход из покоя, раскрытие после сжатия, сжатие перед возвратом в компакт, уход в покой, новое содержимое
  case alertIn, alertGrow, alertShrink, alertOut, alertUpdate
  /// Peek календаря на старте события и его уход
  case calendarPeekOpen, calendarPeekClose
  /// Смена вида раскрытого: форма та же, контент через блюр
  case viewSwap
  /// Строка громкости в раскрытом плеере: высота 175 ↔ 207
  case volumeRow
  /// Компакт/peek календаря меняет размер на месте: музыка появилась или пропала во время окна
  /// календаря (257↔254, 276↔270). У Alcove живьём не проверяли — оценка, берём пружину компакта
  case calendarRestyle
  /// Подложка подгонки выреза (Task 17t): вход из покоя, новое значение на месте, уход обратно в покой.
  /// У Alcove 1.7.9 «переход обычными пружинами формы» (29.09) — своих замеров нет
  case tuningIn, tuningUpdate, tuningOut

  /// Остров раскрылся наведением курсора: на это приложение отвечает тактильным откликом
  public var opensByHover: Bool { self == .hoverOpen || self == .hoverExpand }
}

/// Пружины переходов. Числа — замеры нативного Alcove из capture/analysis/README.md
public enum IslandMotion {
  /// Пружина перехода, замедленная в timeScale раз (IslandMachine.Config.timeScale)
  public static func spring(for transition: IslandTransition, timeScale: Double) -> SpringSpec? {
    spring(for: transition)?.slowed(by: timeScale)
  }

  public static func spring(for transition: IslandTransition) -> SpringSpec? {
    switch transition {
    case .compactIn: SpringSpec(stiffness: 235, damping: 31)
    case .compactOut: SpringSpec(stiffness: 185, damping: 27.5)
    // peek не мерили: берём пружины компакта
    case .peekOpen: SpringSpec(stiffness: 235, damping: 31)
    case .peekClose: SpringSpec(stiffness: 185, damping: 27.5)
    // hover в мини-состояние (режим Alcove) не мерили: берём пружину раскрытия по клику
    case .hoverOpen, .expand: SpringSpec(stiffness: 175, damping: 16)
    // замер видео hover-открытия Alcove 2026-09-26: 202.5/17.5, ζ ≈ 0.62, СКО 0.46 pt.
    // Ширина и высота идут одной пружиной. Схлопывание по уходу курсора — то же smooth(0.4)
    case .hoverExpand: SpringSpec(stiffness: 200, damping: 17.5)
    case .collapse: .smooth(duration: 0.4)
    // оценка: пружину отклика не подгоняли, отклик прерывается раскрытием через ~130 мс,
    // и по кадрам видно только монотонный рост ширины. Мягкая без отскока, та же в обе стороны.
    // На сайте hover — scale 1.075 пружиной 250/14 (motion.md), в нативном отскока не видно
    case .hoverNudge, .hoverNudgeBack: .smooth(duration: 0.13)
    case .hudIn: .smooth(duration: 0.44)
    case .hudOut: .smooth(duration: 0.45)
    // оценка: пружину не подгоняли. Осмотр 26.09 (случайная запись): 175 → 32 за ~0.35 с,
    // ширина с перелётом выше конечной. Берём замеренную пружину hover-открытия, у неё тот же перелёт
    case .hudMorph: SpringSpec(stiffness: 200, damping: 17.5)
    // новый уровень HUD меняет только полоску, размер тот же
    case .hudUpdate: nil
    // замер записи №2 (capture/analysis/README.md): раскрытие в Charging 195 → 357, ζ 0.92.
    // Вход из покоя не мерили: та же пружина, путь почти тот же
    case .alertIn, .alertGrow: SpringSpec(stiffness: 125, damping: 20.5)
    // замер той же записи: Charging → сжатие
    case .alertShrink: SpringSpec(stiffness: 335, damping: 37)
    // не мерили: как уход HUD в покой
    case .alertOut: .smooth(duration: 0.45)
    // новое содержимое того же размера
    case .alertUpdate: nil
    // выведено из замера ui-inspection 3.5: 32 → пик 75.5 за ~0.25 с → 73.5. Перелёт 2/41.5 = 4.8% даёт ζ ≈ 0.69,
    // пик за 0.25 с — ωd = π / 0.25, отсюда k = 305, c = 24.3
    case .calendarPeekOpen: SpringSpec(stiffness: 305, damping: 24.3)
    // там же: 73.5 → 32 за ~0.4 с монотонно
    case .calendarPeekClose: .smooth(duration: 0.4)
    // ui-inspection 3.7: старый вид гаснет в блюр ~0.1 с, новый проявляется ~0.13 с, всего ~0.23 с.
    // Форма не меняется. Тайминг блюра задаёт сам переход AnyTransition.viewSwap: его анимация
    // важнее анимации транзакции, эта пружина на контент не влияет
    case .viewSwap: .smooth(duration: 0.23)
    // замера нет, оценка: на кадрах 28.09 рост без заметного перелёта
    case .volumeRow: .smooth(duration: 0.3)
    // не мерили: тот же масштаб изменения ширины, что у входа в компакт — оценка
    case .calendarRestyle: SpringSpec(stiffness: 235, damping: 31)
    // Task 17t: своих замеров нет, Alcove 1.7.9 «обычные пружины формы» (29.09) — переиспользуем
    // HUD (тоже вход/уход у покоя без музыки) для входа и ухода, компакт — для живой смены значения
    case .tuningIn: .smooth(duration: 0.44)
    case .tuningOut: .smooth(duration: 0.45)
    case .tuningUpdate: SpringSpec(stiffness: 235, damping: 31)
    // замеры сжатия перед сменой (analysis/README.md): из компакта 261 → ~195 — 345/30.5,
    // из HUD 369 → ~199 — 360/38. Одна .smooth(0.33) (≈ 362/38) давала сжатию перед HUD
    // на 2.6 pt меньше хода к моменту раскрытия (demo-сверка 28.09)
    case .shrink: SpringSpec(stiffness: 345, damping: 30.5)
    case .shrinkFromWide: SpringSpec(stiffness: 360, damping: 38)
    case .grow: .spring(duration: 0.45, bounce: 0.1)
    }
  }
}
