import IslandCore
import SwiftUI

/// Раскрытие в плеер масштабирует контент вместе с формой, а не открывает его ростом высоты.
/// Замер видео hover-открытия Alcove 2026-09-26 (кадры 45–52, t 0.825–0.99 с): положение кнопки play,
/// даты и названия относительно верха по центру совпадает с масштабом ширины острова по обеим осям
/// (0.78 при ширине 0.81, 0.87 при 0.89, 1.03 на перелёте 1.03), якорь — верх по центру.
/// Поэтому масштаб один, равный доле ширины, и идёт той же пружиной, что форма
struct OpenScale: ViewModifier, Animatable {
  /// Текущий размер формы: интерполируется пружиной
  var size: CGSize
  /// Итоговый размер: не анимируется, контент раскладывается по нему
  let target: CGSize
  let scalesContent: Bool

  nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(size.width, size.height) }
    set { size = CGSize(width: newValue.first, height: newValue.second) }
  }

  /// Масштаб контента: доля ширины формы от итоговой
  nonisolated static func scale(size: CGSize, target: CGSize) -> CGFloat {
    size.width / max(target.width, 1)
  }

  func body(content: Content) -> some View {
    // без масштаба контент, как раньше, лежит в рамке текущей формы
    let frame = scalesContent ? target : size
    let scale = scalesContent ? Self.scale(size: size, target: target) : 1
    content
      .frame(width: frame.width, height: frame.height, alignment: .top)
      .scaleEffect(scale, anchor: .top)
  }
}

extension AnyTransition {
  /// Вход плеера: контент проявляется из размытия, когда форма прошла большую часть пути.
  /// Замер тех же кадров: яркость контента 8% на 117 мс от начала раскрытия, 34% на 142, 61% на 167,
  /// 87% на 192, полная на 217 мс. Отсюда задержка 90 мс и проявление 130 мс, растянутые timeScale.
  /// Размытие 10 — оценка по виду кадров 45–47, яркость его не отделяет
  static func playerEntrance(timeScale: Double) -> AnyTransition {
    let identity = SlotModifier(opacity: 1, blur: 0)
    return .asymmetric(
      insertion: .modifier(active: SlotModifier(opacity: 0, blur: IslandTiming.slotInBlur), identity: identity)
        .animation(.easeOut(duration: 0.13 * timeScale).delay(0.09 * timeScale)),
      removal: .slot)
  }
}
