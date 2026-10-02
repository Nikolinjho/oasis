/// Шаг клавиш громкости и яркости: 1/16, с Option+Shift — 1/64, как у системы
public enum LevelStep {
  public static func apply(_ level: Double, up: Bool, fine: Bool) -> Double {
    let step = fine ? 1.0 / 64 : 1.0 / 16
    let snapped = (level / step).rounded() * step
    return min(1, max(0, snapped + (up ? step : -step)))
  }
}
